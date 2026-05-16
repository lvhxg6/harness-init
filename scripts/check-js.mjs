import { spawnSync } from 'node:child_process';
import { existsSync, readdirSync, statSync } from 'node:fs';
import path from 'node:path';

const roots = process.argv.slice(2);
const workspaceDir = process.env.HARNESS_WORKSPACE_DIR || 'workspace';
const scanRoots = roots.length
  ? roots
  : [
      `${workspaceDir}/backend/src`,
      `${workspaceDir}/backend/tests`,
      `${workspaceDir}/frontend/src`,
      `${workspaceDir}/tests`,
    ];
const files = [];

function walk(target) {
  if (!existsSync(target)) return;
  const info = statSync(target);
  if (info.isFile()) {
    if (/\.(mjs|js|ts|tsx)$/.test(target)) files.push(target);
    return;
  }
  if (!info.isDirectory()) return;
  for (const entry of readdirSync(target)) {
    if (entry === 'node_modules' || entry === 'dist') continue;
    walk(path.join(target, entry));
  }
}

for (const root of scanRoots) walk(root);

for (const file of files.filter((item) => /\.(mjs|js)$/.test(item))) {
  const result = spawnSync(process.execPath, ['--check', file], { stdio: 'inherit' });
  if (result.status !== 0) process.exit(result.status || 1);
}

console.log(`[check-js] Checked ${files.length} source files`);
