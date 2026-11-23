const bytes = new TextEncoder();
const text = new TextDecoder();

export function token(size = 32) {
  return base64Url(crypto.getRandomValues(new Uint8Array(size)));
}

function base64Url(value) {
  return btoa(String.fromCharCode(...value)).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

function decode(value) {
  return Uint8Array.from(atob(value.replace(/-/g, "+").replace(/_/g, "/")), x => x.charCodeAt(0));
}

export async function proofHash(proof) {
  const digest = await crypto.subtle.digest("SHA-256", bytes.encode(proof));
  return Array.from(new Uint8Array(digest), x => x.toString(16).padStart(2, "0")).join("");
}

export function equalHash(a, b) {
  if (a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return diff === 0;
}

async function key(secret) {
  const input = decode(secret);
  if (input.length !== 32) throw new Error("invalid encryption configuration");
  return crypto.subtle.importKey("raw", input, "AES-GCM", false, ["encrypt", "decrypt"]);
}

export async function encrypt(secret, purpose, data) {
  const iv = crypto.getRandomValues(new Uint8Array(12));
  const encrypted = await crypto.subtle.encrypt(
    { name: "AES-GCM", iv, additionalData: bytes.encode(purpose) },
    await key(secret), bytes.encode(JSON.stringify(data)),
  );
  return base64Url(iv) + "." + base64Url(new Uint8Array(encrypted));
}

export async function decrypt(secret, purpose, value) {
  const [iv, encrypted, extra] = value.split(".");
  if (!iv || !encrypted || extra !== undefined) throw new Error("invalid sealed value");
  const payload = await crypto.subtle.decrypt(
    { name: "AES-GCM", iv: decode(iv), additionalData: bytes.encode(purpose) },
    await key(secret), decode(encrypted),
  );
  return JSON.parse(text.decode(payload));
}
