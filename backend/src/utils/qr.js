const crypto = require('crypto');
const env = require('../config/env');

function getKey() {
  return Buffer.from(env.QR_SECRET, 'base64'); // validated as 32 bytes at startup
}

/**
 * Encrypt a JSON payload with AES-256-GCM.
 * Output format: base64(iv):base64(ciphertext):base64(authTag)
 */
function encryptQrPayload(payload) {
  const iv = crypto.randomBytes(12);
  const cipher = crypto.createCipheriv('aes-256-gcm', getKey(), iv);
  const ciphertext = Buffer.concat([cipher.update(JSON.stringify(payload), 'utf8'), cipher.final()]);
  const authTag = cipher.getAuthTag();
  return `${iv.toString('base64')}:${ciphertext.toString('base64')}:${authTag.toString('base64')}`;
}

/** Decrypt qrData; returns the payload object or null when invalid/tampered. */
function decryptQrPayload(qrData) {
  try {
    const parts = String(qrData).split(':');
    if (parts.length !== 3) return null;
    const [iv, ciphertext, authTag] = parts.map((p) => Buffer.from(p, 'base64'));
    const decipher = crypto.createDecipheriv('aes-256-gcm', getKey(), iv);
    decipher.setAuthTag(authTag);
    const plaintext = Buffer.concat([decipher.update(ciphertext), decipher.final()]);
    return JSON.parse(plaintext.toString('utf8'));
  } catch {
    return null;
  }
}

/** Fresh QR token: { t: issuedAt ms, n: nonce }. */
function issueQrToken() {
  const issuedAt = Date.now();
  const payload = { t: issuedAt, n: crypto.randomBytes(8).toString('hex') };
  return { qrData: encryptQrPayload(payload), issuedAt };
}

/**
 * A scanned code is valid for qrRefreshSeconds + 15s grace.
 * Small negative age tolerated for clock skew.
 */
function isQrPayloadFresh(payload, refreshSeconds) {
  if (!payload || typeof payload.t !== 'number' || typeof payload.n !== 'string') return false;
  const age = Date.now() - payload.t;
  return age >= -10000 && age <= (refreshSeconds + 15) * 1000;
}

module.exports = { encryptQrPayload, decryptQrPayload, issueQrToken, isQrPayloadFresh };
