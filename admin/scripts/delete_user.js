#!/usr/bin/env node
/*
 * Full delete of an iSign admin/user:
 *   1. Firebase Auth account   (real revocation)
 *   2. Firestore users/{uid}
 *   3. Devices listed on that profile
 *
 * Requires a Firebase service account key.
 *
 * Setup:
 *   - Download a service account key from Firebase/Google Cloud Console
 *     (Project isign-fsl -> Project settings -> Service accounts ->
 *      Generate new private key). Save as firebase-sa.json.
 *
 * Usage:
 *   GOOGLE_APPLICATION_CREDENTIALS=firebase-sa.json \
 *     node delete_user.js --uid <uid>
 *
 *   GOOGLE_APPLICATION_CREDENTIALS=firebase-sa.json \
 *     node delete_user.js --email <email>
 */
const { initializeApp, applicationDefault } = require('firebase-admin/app');
const { getAuth } = require('firebase-admin/auth');
const { getFirestore } = require('firebase-admin/firestore');

const args = process.argv.slice(2);
function flag(name) {
  const i = args.indexOf(name);
  return i >= 0 && args[i + 1] ? args[i + 1].trim() : null;
}

const uid = flag('--uid');
const email = flag('--email');

if (!process.env.GOOGLE_APPLICATION_CREDENTIALS) {
  console.error('ERROR: GOOGLE_APPLICATION_CREDENTIALS must point to a service account JSON key.');
  process.exit(1);
}
if (!uid && !email) {
  console.error('ERROR: pass --uid <uid> or --email <email>.');
  process.exit(1);
}

initializeApp({ credential: applicationDefault() });
const auth = getAuth();
const db = getFirestore();

(async () => {
  // Resolve target uid
  let targetUid = uid;
  if (!targetUid) {
    try {
      const user = await auth.getUserByEmail(email);
      targetUid = user.uid;
      console.log(`Resolved email "${email}" -> uid ${targetUid}`);
    } catch (e) {
      const code = (e && e.errorInfo && e.errorInfo.code) || (e && e.code) || '';
      if (code === 'auth/user-not-found') {
        console.error(`No auth account found for email "${email}". Aborting.`);
        process.exit(1);
      }
      throw e;
    }
  }

  // 1) Auth account
  try {
    await auth.deleteUser(targetUid);
    console.log(`[ok] Firebase Auth account deleted: ${targetUid}`);
  } catch (e) {
    const code = (e && e.errorInfo && e.errorInfo.code) || (e && e.code) || '';
    if (code === 'auth/user-not-found') {
      console.log(`[ok] Firebase Auth account not found (already gone): ${targetUid}`);
    } else {
      console.error(`[!] Auth delete failed: ${code}`);
    }
  }

  // 2) Firestore profile + devices
  try {
    const ref = db.collection('users').doc(targetUid);
    const snap = await ref.get();
    if (!snap.exists) {
      console.log(`[ok] Firestore users/${targetUid} not found (already gone).`);
    } else {
      const data = snap.data();
      const devices = Array.isArray(data.devices) ? data.devices : [];
      await ref.delete();
      console.log(`[ok] Firestore users/${targetUid} deleted.`);

      for (const deviceId of devices) {
        try {
          await db.collection('devices').doc(String(deviceId)).delete();
          console.log(`[ok] devices/${deviceId} deleted.`);
        } catch (de) {
          console.warn(`[!] could not delete devices/${deviceId}: ${de.message}`);
        }
      }
    }
  } catch (e) {
    console.error(`[!] Firestore cleanup failed (auth already handled): ${e.message}`);
    process.exitCode = 1;
  }

  console.log('Done.');
})().catch((e) => {
  console.error('Fatal:', e && e.message ? e.message : e);
  process.exit(1);
});