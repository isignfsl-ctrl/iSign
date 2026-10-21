import fs from 'node:fs';
import crypto from 'node:crypto';

// Usage: node tools/set_app_version.mjs <versionCode> <versionName> <apkUrl> <notes> [force]
// Publishes Firestore doc config/appVersion consumed by the in-app updater.
const [code, name, apkUrl, notes = '', force = 'false'] = process.argv.slice(2);
if (!code || !apkUrl) {
  console.error('usage: node tools/set_app_version.mjs <versionCode> <versionName> <apkUrl> <notes> [force]');
  process.exit(1);
}

const keyPath = process.env.SA_KEY || 'serviceAccountKey.json';
const sa = JSON.parse(fs.readFileSync(keyPath, 'utf8'));
const b64url = (buf) => Buffer.from(buf).toString('base64url');
const header = b64url(JSON.stringify({ alg: 'RS256', typ: 'JWT' }));
const now = Math.floor(Date.now() / 1000);
const payload = b64url(JSON.stringify({
  iss: sa.client_email,
  scope: 'https://www.googleapis.com/auth/datastore',
  aud: 'https://oauth2.googleapis.com/token',
  iat: now, exp: now + 3600,
}));
const sig = crypto.createSign('RSA-SHA256').update(`${header}.${payload}`).sign(sa.private_key);
const jwt = `${header}.${payload}.${Buffer.from(sig).toString('base64url')}`;

const tokenRes = await fetch('https://oauth2.googleapis.com/token', {
  method: 'POST',
  headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
  body: `grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer&assertion=${jwt}`,
});
const token = await tokenRes.json();
if (!token.access_token) { console.error('TOKEN ERROR', token); process.exit(1); }

const headers = { Authorization: `Bearer ${token.access_token}`, 'Content-Type': 'application/json' };
const base = 'https://firestore.googleapis.com/v1/projects/isign-fsl/databases/(default)/documents';
const fields = {
  versionCode: { integerValue: String(Number(code)) },
  versionName: { stringValue: String(name) },
  apkUrl: { stringValue: String(apkUrl) },
  notes: { stringValue: String(notes) },
  force: { booleanValue: force === 'true' },
  updatedAt: { stringValue: new Date().toISOString() },
};

const docUrl = `${base}/config/appVersion`;
const get = await fetch(docUrl, { headers });
if (get.ok) {
  const res = await fetch(`${docUrl}?currentDocument.exists=true`, {
    method: 'PATCH', headers,
    body: JSON.stringify({ fields }),
  });
  if (!res.ok) { console.error('PATCH FAILED', res.status, await res.text()); process.exit(1); }
  console.log(`updated config/appVersion -> ${name} (${code})`);
} else if (get.status === 404) {
  const res = await fetch(`${base}/config?documentId=appVersion`, {
    method: 'POST', headers,
    body: JSON.stringify({ fields }),
  });
  if (!res.ok) { console.error('CREATE FAILED', res.status, await res.text()); process.exit(1); }
  console.log(`created config/appVersion -> ${name} (${code})`);
} else {
  console.error('GET FAILED', get.status, await get.text());
  process.exit(1);
}
