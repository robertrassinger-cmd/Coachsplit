'use strict';
const assert = require('node:assert/strict');
const { spawn } = require('node:child_process');
const fs = require('node:fs');
const path = require('node:path');

const port = 18787;
const dataFile = path.join(__dirname, '.smoke-data.json');
try { fs.unlinkSync(dataFile); } catch (_) {}
const child = spawn(process.execPath, ['server.js'], {
  cwd: __dirname,
  env: { ...process.env, PORT: String(port), COACHSPLIT_DATA_FILE: dataFile },
  stdio: ['ignore', 'pipe', 'inherit'],
});
const base = `http://127.0.0.1:${port}`;
const sleep = ms => new Promise(resolve => setTimeout(resolve, ms));
async function json(url, options={}) {
  const response = await fetch(url, options);
  const body = await response.json();
  if (!response.ok) throw new Error(`${response.status}: ${JSON.stringify(body)}`);
  return body;
}
(async () => {
  await sleep(250);
  const created = await json(`${base}/api/sessions`, {
    method: 'POST', headers: {'content-type':'application/json'},
    body: JSON.stringify({
      deviceId:'admin-1', deviceName:'Admin', appBaseUrl:'https://coachsplit.example',
      competition:{id:'race-1', name:'Test'},
      checkpoints:[{id:'start',name:'Start',kind:'start'},{id:'finish',name:'Ziel',kind:'finish'}],
    }),
  });
  assert.match(created.joinUrl, /\?join=/);
  const joined = await json(`${base}/api/join`, {
    method:'POST', headers:{'content-type':'application/json'},
    body:JSON.stringify({joinToken:created.joinToken,deviceId:'helper-1',displayName:'Anna'}),
  });
  assert.equal(joined.checkpointId, null);
  const adminHeaders = {'content-type':'application/json', authorization:`Bearer ${created.accessToken}`};
  await json(`${base}/api/assignments`, {
    method:'POST', headers:adminHeaders,
    body:JSON.stringify({sessionId:'race-1',deviceId:'helper-1',checkpointId:'finish'}),
  });
  const helperHeaders = {'content-type':'application/json', authorization:`Bearer ${joined.accessToken}`};
  const heartbeat = await json(`${base}/api/devices/heartbeat`, {
    method:'POST', headers:helperHeaders,
    body:JSON.stringify({sessionId:'race-1',deviceId:'helper-1',pendingEventCount:3}),
  });
  assert.equal(heartbeat.checkpointId, 'finish');
  const state = await json(`${base}/api/collaboration/state?sessionId=race-1`, {headers:adminHeaders});
  assert.equal(state.devices[0].displayName, 'Anna');
  assert.equal(state.devices[0].pendingEventCount, 3);
  console.log('CoachSplit collaboration smoke test passed.');
})().finally(async () => {
  child.kill('SIGTERM');
  await sleep(100);
  try { fs.unlinkSync(dataFile); } catch (_) {}
}).catch(error => { console.error(error); process.exitCode = 1; });
