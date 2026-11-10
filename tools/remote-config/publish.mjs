// Publishes tools/remote-config/template.json to Firebase Remote Config (REST API).
// GET the current template (ETag) -> merge our parameters into it (other parameters and conditions are kept)
// -> PUT with If-Match. See README.md.
//
//   node tools/remote-config/publish.mjs            # dry run: prints the merged template
//   node tools/remote-config/publish.mjs --publish  # publishes
//
// Token: $ACCESS_TOKEN, or `gcloud auth print-access-token --impersonate-service-account=$IMPERSONATE`
// (IMPERSONATE defaults to claude-dev@devfest2026-oauthmountains.iam.gserviceaccount.com; set it empty to use
// your own gcloud login). No service account key is used.
import { execSync } from 'node:child_process';
import { readFileSync } from 'node:fs';

const project = process.env.PROJECT_ID ?? 'devfest2026-oauthmountains';
const impersonate = process.env.IMPERSONATE ?? `claude-dev@${project}.iam.gserviceaccount.com`;
const url = `https://firebaseremoteconfig.googleapis.com/v1/projects/${project}/remoteConfig`;
const publish = process.argv.includes('--publish');

function token() {
  if (process.env.ACCESS_TOKEN) return process.env.ACCESS_TOKEN;
  const flag = impersonate ? ` --impersonate-service-account=${impersonate}` : '';
  return execSync(`gcloud auth print-access-token${flag}`, { encoding: 'utf8' }).trim();
}

const ours = JSON.parse(readFileSync(new URL('./template.json', import.meta.url), 'utf8'));
const auth = { Authorization: `Bearer ${token()}` };

const res = await fetch(url, { headers: auth });
if (!res.ok) {
  console.error(`GET ${res.status}: ${await res.text()}`);
  process.exit(1);
}
const etag = res.headers.get('etag');
const current = await res.json();
const merged = { ...current, parameters: { ...(current.parameters ?? {}), ...ours.parameters } };
delete merged.version; // set by the server

const kept = Object.keys(current.parameters ?? {}).filter((k) => !(k in ours.parameters));
console.log(`ETag ${etag}; updating ${Object.keys(ours.parameters).join(', ')}; keeping ${kept.join(', ') || '(none)'}`);

if (!publish) {
  console.log(JSON.stringify(merged, null, 2));
  console.log('Dry run. Add --publish to publish.');
  process.exit(0);
}

const put = await fetch(url, {
  method: 'PUT',
  headers: { ...auth, 'Content-Type': 'application/json; UTF-8', 'If-Match': etag ?? '*' },
  body: JSON.stringify(merged),
});
if (!put.ok) {
  console.error(`PUT ${put.status}: ${await put.text()}`);
  process.exit(1);
}
const published = await put.json();
console.log(`Published version ${published.version?.versionNumber} (ETag ${put.headers.get('etag')})`);
