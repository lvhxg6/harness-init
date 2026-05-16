#!/usr/bin/env node
import fs from 'node:fs';

const file = process.argv[2];
if (!file || !fs.existsSync(file)) {
  console.error(`Missing tasks file: ${file || '<none>'}`);
  process.exit(1);
}

const text = fs.readFileSync(file, 'utf8');
const tasks = [];
let current = null;
let activeList = '';

function clean(value = '') {
  return value.trim().replace(/^['"]|['"]$/g, '');
}

for (const rawLine of text.split(/\r?\n/)) {
  const line = rawLine.replace(/\t/g, '  ');
  const newTask = line.match(/^\s*-\s+id:\s*(.+?)\s*$/);
  if (newTask) {
    current = { id: clean(newTask[1]), title: '', type: 'implementation', scope: [], verify: [] };
    tasks.push(current);
    activeList = '';
    continue;
  }
  if (!current) continue;

  const scalar = line.match(/^\s+(title|type):\s*(.*?)\s*$/);
  if (scalar) {
    current[scalar[1]] = clean(scalar[2]);
    activeList = '';
    continue;
  }

  const anyListStart = line.match(/^\s+([A-Za-z0-9_-]+):\s*$/);
  if (anyListStart) {
    activeList = ['scope', 'verify'].includes(anyListStart[1]) ? anyListStart[1] : '';
    continue;
  }

  const listItem = line.match(/^\s+-\s*(.*?)\s*$/);
  if (listItem && activeList) {
    current[activeList].push(clean(listItem[1]));
  }
}

const invalid = tasks.filter((task) => !task.id || /\s/.test(task.id));
if (tasks.length === 0 || invalid.length > 0) {
  console.error(`Invalid tasks.yaml: expected tasks with non-empty id values without spaces`);
  process.exit(1);
}

for (const task of tasks) {
  const title = task.title || task.id;
  const scope = task.scope.length > 0 ? task.scope.join(',') : 'workspace';
  console.log([task.id, title, task.type || 'implementation', scope].map((value) => String(value).replace(/\|/g, '/')).join('|'));
}
