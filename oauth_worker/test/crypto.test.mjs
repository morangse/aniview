import test from "node:test";
import assert from "node:assert/strict";
import { decrypt, encrypt, equalHash, proofHash, token } from "../src/crypto.mjs";

test("proof has a deterministic keyed digest comparison", async () => {
  const secret = token();
  assert.match(secret, /^[A-Za-z0-9_-]{43}$/);
  const hash = await proofHash(secret);
  assert.equal(hash.length, 64);
  assert.equal(equalHash(hash, await proofHash(secret)), true);
  assert.equal(equalHash(hash, await proofHash(token())), false);
});

test("sealed credentials are encrypted, purpose-bound and reject tampering", async () => {
  const key = token();
  const sample = { access_token: "mock-item-test-only" };
  const value = await encrypt(key, "pairing", sample);
  assert.equal(value.includes(sample.access_token), false);
  assert.deepEqual(await decrypt(key, "pairing", value), sample);
  await assert.rejects(decrypt(key, "refresh", value));
  await assert.rejects(decrypt(token(), "pairing", value));
});
