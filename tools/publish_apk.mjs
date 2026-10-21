import fs from 'node:fs';
import { execFileSync, execSync } from 'node:child_process';

// Usage: node tools/publish_apk.mjs <apkPath> <versionName> <versionCode> [notes]
// Creates (or refreshes) a GitHub release and uploads the APK as an asset.
// Auth: PAT parsed from the git remote URL (never stored in files).
// Prints the public asset download URL as the last line.

const [apkPath, name, code, notes = ''] = process.argv.slice(2);
if (!apkPath || !name || !code) {
  console.error('usage: node tools/publish_apk.mjs <apkPath> <versionName> <versionCode> [notes]');
  process.exit(1);
}

if (!fs.existsSync(apkPath)) {
  console.error(`APK not found: ${apkPath}`);
  process.exit(1);
}

const remote = execSync('git remote get-url origin', { encoding: 'utf8' }).trim();
const tokenMatch = remote.match(/:([^:@]+)@github\.com/);
if (!tokenMatch) {
  console.error('Could not parse PAT from git remote URL');
  process.exit(1);
}
const token = tokenMatch[1];

const ownerRepo = 'isignfsl-ctrl/iSign';
const tag = `v${name}-${code}`;
const assetName = `iSign-${name}+${code}.apk`;
const apiUrl = `https://api.github.com/repos/${ownerRepo}`;

const gh = (path, opts = {}) =>
  fetch(`${apiUrl}${path}`, {
    ...opts,
    headers: {
      Authorization: `Bearer ${token}`,
      Accept: 'application/vnd.github+json',
      'User-Agent': 'isign-release',
      ...(opts.body && !(opts.body instanceof Uint8Array) && !(opts.body instanceof ArrayBuffer)
        ? { 'Content-Type': 'application/json' }
        : {}),
      ...opts.headers,
    },
  });

// 1) Find or create the release for this tag
let release = null;
const existing = await gh(`/releases/tags/${encodeURIComponent(tag)}`);
if (existing.ok) {
  release = await existing.json();
  // Remove a previous upload of this asset so re-runs are clean
  for (const asset of release.assets || []) {
    if (asset.name === assetName) {
      await gh(`/releases/assets/${asset.id}`, { method: 'DELETE' });
    }
  }
} else {
  const created = await gh('/releases', {
    method: 'POST',
    body: JSON.stringify({
      tag_name: tag,
      name: `iSign ${name} (build ${code})`,
      body: notes,
      draft: false,
      prerelease: false,
    }),
  });
  if (!created.ok) {
    console.error('Release create failed', created.status, await created.text());
    process.exit(1);
  }
  release = await created.json();
}

// 2) Upload the APK (curl streams the file; GitHub asset limit is 2 GB)
const uploadUrl = `https://uploads.github.com/repos/${ownerRepo}/releases/${release.id}/assets?name=${encodeURIComponent(assetName)}`;
try {
  execFileSync('curl.exe', [
    '-sS', '--fail-with-body',
    '-X', 'POST',
    '-H', `Authorization: Bearer ${token}`,
    '-H', 'Content-Type: application/vnd.android.package-archive',
    '--data-binary', `@${apkPath}`,
    uploadUrl,
  ], { stdio: ['ignore', 'pipe', 'inherit'] });
} catch (e) {
  console.error('Asset upload failed');
  process.exit(1);
}

// 3) Print the public download URL (repo is public)
console.log(`https://github.com/${ownerRepo}/releases/download/${tag}/${assetName}`);
