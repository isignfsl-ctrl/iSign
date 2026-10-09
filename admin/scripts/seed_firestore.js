const fs = require('fs');
const path = require('path');

const PROJECT_ID = 'isign-fsl';
const API_KEY = 'AIzaSyA5aAAjsF_ZhQvRAAqcahk7OZM7nHuxAeA';
const JSON_PATH = path.join(__dirname, '..', '..', 'assets', 'seed', 'fsl_dictionary.json');

async function getToken() {
  const res = await fetch(
    `https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=${API_KEY}`,
    { method: 'POST', headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ returnSecureToken: true }) }
  );
  const data = await res.json();
  if (!data.idToken) throw new Error('Auth failed: ' + JSON.stringify(data));
  return data.idToken;
}

function toValue(v) {
  if (typeof v === 'string') return { stringValue: v };
  if (typeof v === 'number') return Number.isInteger(v) ? { integerValue: v } : { doubleValue: v };
  if (typeof v === 'boolean') return { booleanValue: v };
  if (Array.isArray(v)) return { arrayValue: { values: v.map(toValue) } };
  if (v instanceof Date) return { timestampValue: v.toISOString() };
  if (v === null) return { nullValue: null };
  if (typeof v === 'object') return { mapValue: { fields: toFields(v) } };
  return { stringValue: String(v) };
}

function toFields(obj) {
  const fields = {};
  for (const [k, v] of Object.entries(obj)) {
    fields[k] = toValue(v);
  }
  return fields;
}

async function addDocument(token, data) {
  const url = `https://firestore.googleapis.com/v1/projects/${PROJECT_ID}/databases/(default)/documents/catalog`;
  const body = { fields: toFields(data) };
  const res = await fetch(url, {
    method: 'POST',
    headers: { 'Authorization': `Bearer ${token}`, 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
  });
  if (!res.ok) {
    const err = await res.text();
    throw new Error(`Firestore error (${res.status}): ${err}`);
  }
  return res.json();
}

async function clearCatalog(token) {
  console.log('Clearing existing catalog entries...');
  const url = `https://firestore.googleapis.com/v1/projects/${PROJECT_ID}/databases/(default)/documents/catalog`;
  let deleted = 0;
  while (true) {
    const res = await fetch(url + '?pageSize=500', {
      headers: { 'Authorization': `Bearer ${token}` },
    });
    if (!res.ok) break;
    const body = await res.json();
    const docs = body.documents || [];
    if (docs.length === 0) break;
    for (const doc of docs) {
      const docUrl = doc.name;
      const delRes = await fetch(docUrl, {
        method: 'DELETE',
        headers: { 'Authorization': `Bearer ${token}` },
      });
      if (delRes.ok) deleted++;
    }
    console.log(`  Deleted ${deleted} documents so far...`);
  }
  console.log(`  Cleared ${deleted} existing catalog entries.\n`);
}

async function seed() {
  if (!fs.existsSync(JSON_PATH)) {
    console.error(`ERROR: Seed data not found at ${JSON_PATH}`);
    process.exit(1);
  }

  const raw = fs.readFileSync(JSON_PATH, 'utf-8');
  const parsed = JSON.parse(raw);
  const categories = parsed.categories;

  if (!categories || !Array.isArray(categories)) {
    console.error('ERROR: Invalid JSON — missing "categories" array');
    process.exit(1);
  }

  console.log('Authenticating with Firebase...');
  const token = await getToken();
  console.log('Connected.\n');

  await clearCatalog(token);

  let signId = 1;

  for (let catIdx = 0; catIdx < categories.length; catIdx++) {
    const cat = categories[catIdx];
    const signs = cat.signs || [];
    console.log(`  Category: ${cat.category_name} (id=${catIdx})`);

    for (const sign of signs) {
      await addDocument(token, {
        signId,
        signName: sign.sign_name,
        signNameEn: sign.sign_name_en || '',
        description: sign.description || '',
        descriptionEn: sign.description_en || '',
        categoryId: catIdx,
        version: 1,
        landmarkSamplePaths: [],
        updatedAt: new Date().toISOString(),
        updatedBy: 'seed-script',
      });
      console.log(`    [${signId}] ${sign.sign_name}`);
      signId++;
    }
  }

  console.log(`\nDone! Seeded ${signId - 1} signs across ${categories.length} categories.`);
}

seed().catch((err) => {
  console.error('\nSeed failed:', err.message);
  process.exit(1);
});
