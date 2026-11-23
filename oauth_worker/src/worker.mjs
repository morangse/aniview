import { DurableObject } from "cloudflare:workers";
import { decrypt, encrypt, equalHash, proofHash, token } from "./crypto.mjs";

const ttl = 5 * 60 * 1000;
const idPattern = /^[A-Za-z0-9_-]{43}$/;
const headers = { "Cache-Control": "no-store", "Referrer-Policy": "no-referrer" };
const json = (data, status = 200) => Response.json(data, { status, headers });

async function body(request) {
  const reader = request.body?.getReader();
  if (!reader) throw new Error("body missing");
  const decoder = new TextDecoder();
  let input = "";
  let total = 0;
  try {
    for (;;) {
      const part = await reader.read();
      if (part.done) break;
      total += part.value.length;
      if (total > 8192) throw new Error("body too large");
      input += decoder.decode(part.value, { stream: true });
    }
    return JSON.parse(input + decoder.decode());
  } finally {
    await reader.cancel();
  }
}

async function exchange(env, grant) {
  const response = await fetch("https://bgm.tv/oauth/access_token", {
    method: "POST",
    redirect: "error",
    signal: AbortSignal.timeout(8000),
    headers: {
      "Content-Type": "application/x-www-form-urlencoded",
      "Accept": "application/json",
      "User-Agent": "ran/AniView/0.2.0 (OAuth)",
    },
    body: new URLSearchParams({
      client_id: env.BANGUMI_APP_ID,
      client_secret: env.BANGUMI_APP_SECRET,
      redirect_uri: env.BANGUMI_REDIRECT_URI,
      ...grant,
    }),
  });
  if (!response.ok) throw new Error("token exchange failed");
  const result = await response.json();
  if (typeof result.access_token !== "string" || result.access_token.length > 1024) {
    throw new Error("invalid grant");
  }
  const handle = typeof result.refresh_token === "string" && result.refresh_token.length <= 1024
    ? await encrypt(env.TOKEN_KEY, "refresh", {
        value: result.refresh_token,
        deadline: Date.now() + 180 * 24 * 60 * 60 * 1000,
      })
    : null;
  return {
    access_token: result.access_token,
    expires_in: result.expires_in,
    refresh_handle: handle,
  };
}

export class Pairing extends DurableObject {
  constructor(ctx, env) {
    super(ctx, env);
    this.ctx.storage.sql.exec(
      "CREATE TABLE IF NOT EXISTS pairing (id INTEGER PRIMARY KEY, proof TEXT, expiry INTEGER, stage TEXT, sealed TEXT)",
    );
  }

  async start(proof) {
    const expires = Date.now() + ttl;
    this.ctx.storage.sql.exec("INSERT INTO pairing VALUES (1, ?, ?, 'pending', NULL)", proof, expires);
    await this.ctx.storage.setAlarm(expires);
  }

  async callback(state, code) {
    const sql = this.ctx.storage.sql;
    const claimed = sql.exec(
      "UPDATE pairing SET stage = 'exchanging' WHERE id = 1 AND expiry > ? AND stage = 'pending' RETURNING id",
      Date.now(),
    ).toArray();
    if (claimed.length !== 1) return false;
    try {
      const response = await exchange(this.env, { grant_type: "authorization_code", code, state });
      const sealed = await encrypt(this.env.TOKEN_KEY, "pairing", response);
      sql.exec("UPDATE pairing SET stage = 'ready', sealed = ? WHERE id = 1 AND expiry > ?", sealed, Date.now());
      return true;
    } catch {
      sql.exec("UPDATE pairing SET stage = 'failed' WHERE id = 1");
      return false;
    }
  }

  async claim(proof) {
    const digest = await proofHash(proof);
    const sql = this.ctx.storage.sql;
    const row = sql.exec("SELECT proof, stage, sealed FROM pairing WHERE id = 1 AND expiry > ?", Date.now())
      .toArray()[0];
    if (!row || !equalHash(row.proof, digest)) return { status: "missing" };
    if (row.stage === "pending" || row.stage === "exchanging") return { status: "waiting" };
    sql.exec("DELETE FROM pairing WHERE id = 1");
    if (row.stage !== "ready") return { status: "missing" };
    return { status: "ready", data: await decrypt(this.env.TOKEN_KEY, "pairing", row.sealed) };
  }

  async alarm() {
    await this.ctx.storage.deleteAll();
  }
}

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    if (!env.BANGUMI_APP_ID || !env.BANGUMI_APP_SECRET || !env.BANGUMI_REDIRECT_URI || !env.TOKEN_KEY) {
      return json({ error: "authorization_not_configured" }, 503);
    }
    const limit = await env.AUTH_RATE.limit({ key: request.headers.get("CF-Connecting-IP") ?? "local" });
    if (!limit.success) return json({ error: "rate_limited" }, 429);
    if (request.method === "GET" && url.pathname === "/auth/callback") {
      const state = url.searchParams.get("state") ?? "";
      const code = url.searchParams.get("code") ?? "";
      const accepted = idPattern.test(state) && code.length > 0 && code.length <= 1024
        && await env.PAIRINGS.getByName(state).callback(state, code);
      return new Response(
        accepted ? "授权完成，请返回 AniView 确认。" : "授权无效或已过期，请返回 AniView 重试。",
        { status: accepted ? 200 : 400, headers: { ...headers, "Content-Type": "text/plain; charset=utf-8" } },
      );
    }
    if (request.method !== "POST") return json({ error: "not_found" }, 404);
    try {
      const payload = await body(request);
      if (url.pathname === "/auth/start" && /^[a-f0-9]{64}$/.test(payload.hash)) {
        const state = token();
        await env.PAIRINGS.getByName(state).start(payload.hash);
        const authorize = new URL("https://bgm.tv/oauth/authorize");
        authorize.search = new URLSearchParams({
          client_id: env.BANGUMI_APP_ID,
          redirect_uri: env.BANGUMI_REDIRECT_URI,
          response_type: "code", state,
        }).toString();
        return json({ state, authorize_url: authorize.href });
      }
      if (url.pathname === "/auth/claim" && idPattern.test(payload.state) && idPattern.test(payload.proof)) {
        const outcome = await env.PAIRINGS.getByName(payload.state).claim(payload.proof);
        if (outcome.status === "waiting") return json({ pending: true }, 202);
        return outcome.status === "ready" ? json(outcome.data) : json({ error: "expired" }, 404);
      }
      if (url.pathname === "/auth/refresh" && typeof payload.handle === "string" && payload.handle.length < 4096) {
        const grant = await decrypt(env.TOKEN_KEY, "refresh", payload.handle);
        if (grant.deadline < Date.now()) return json({ error: "expired" }, 401);
        return json(await exchange(env, { grant_type: "refresh_token", refresh_token: grant.value }));
      }
      return json({ error: "invalid_request" }, 400);
    } catch {
      // Provider responses can contain credentials. Keep diagnostics out of logs.
      return json({ error: "authorization_failed" }, 400);
    }
  },
};
