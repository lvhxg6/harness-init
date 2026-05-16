#!/usr/bin/env node
import fs from 'node:fs';
import path from 'node:path';

const args = process.argv.slice(2);
const command = args.shift();

function readJson(file, fallback) {
  try {
    return JSON.parse(fs.readFileSync(file, 'utf8'));
  } catch {
    return fallback;
  }
}

function writeJson(file, value) {
  fs.mkdirSync(path.dirname(file), { recursive: true });
  fs.writeFileSync(file, `${JSON.stringify(value, null, 2)}\n`);
}

function appendJsonl(file, value) {
  fs.mkdirSync(path.dirname(file), { recursive: true });
  fs.appendFileSync(file, `${JSON.stringify(value)}\n`);
}

function opt(name, fallback = '') {
  const index = args.indexOf(`--${name}`);
  if (index === -1) return fallback;
  return args[index + 1] ?? fallback;
}

function hasFlag(name) {
  return args.includes(`--${name}`);
}

function nowIso() {
  return new Date().toISOString();
}

function statePath(runDir) {
  return path.join(runDir, 'state.json');
}

function timelinePath(runDir) {
  return path.join(runDir, 'timeline.jsonl');
}

function statusPath(runDir) {
  return path.join(runDir, 'status.md');
}

function checkpointPath(runDir) {
  return path.join(runDir, 'checkpoint.json');
}

function progressPath(runDir) {
  return path.join(runDir, 'progress.json');
}

function loadState(runDir) {
  return normalizeState(readJson(statePath(runDir), {
    feature: '',
    status: 'running',
    workspace: 'workspace',
    liveMode: '0',
    startedAt: nowIso(),
    updatedAt: nowIso(),
    currentStage: '',
    currentTask: '',
    blockedCategory: '',
    blockedReason: '',
    latestVerifyLog: '',
    latestLiveLog: '',
    currentPid: '',
    currentPidStage: '',
    stages: [],
  }));
}

function saveState(runDir, state) {
  state.updatedAt = nowIso();
  writeJson(statePath(runDir), state);
  writeStatus(runDir, state);
}

function updateCheckpoint(runDir, stage) {
  const checkpoint = readJson(checkpointPath(runDir), { stages: {} });
  checkpoint.stages ||= {};
  checkpoint.stages[stage.id] = {
    status: stage.status,
    label: stage.label,
    taskId: stage.taskId || '',
    startedAt: stage.startedAt || '',
    endedAt: stage.endedAt || '',
    message: stage.message || '',
  };
  checkpoint.updatedAt = nowIso();
  writeJson(checkpointPath(runDir), checkpoint);
}

function secondsBetween(start, end = new Date()) {
  if (!start) return 0;
  const value = Math.max(0, Math.floor((new Date(end).getTime() - new Date(start).getTime()) / 1000));
  return Number.isFinite(value) ? value : 0;
}

function fmt(seconds) {
  const h = Math.floor(seconds / 3600);
  const m = Math.floor((seconds % 3600) / 60);
  const s = seconds % 60;
  return `${String(h).padStart(2, '0')}:${String(m).padStart(2, '0')}:${String(s).padStart(2, '0')}`;
}

function statusRank(status) {
  return {
    FAILED: 0,
    BLOCKED: 1,
    INTERRUPTED: 2,
    RUNNING: 3,
    DONE: 4,
    SKIPPED: 5,
    PENDING: 6,
    STOPPED: 7,
  }[status] ?? 6;
}

function normalizeState(state) {
  state.feature ||= '';
  state.status ||= 'running';
  state.workspace ||= 'workspace';
  state.liveMode ||= '0';
  state.startedAt ||= nowIso();
  state.updatedAt ||= nowIso();
  state.currentStage ||= '';
  state.currentTask ||= '';
  state.blockedCategory ||= '';
  state.blockedReason ||= '';
  state.lastBlockedCategory ||= '';
  state.lastBlockedReason ||= '';
  state.lastBlockedAt ||= '';
  state.latestVerifyLog ||= '';
  state.latestLiveLog ||= '';
  state.currentPid ||= '';
  state.currentPidStage ||= '';
  state.resumeCount ||= 0;
  state.runEpoch ||= 0;
  state.lastResumeAt ||= '';
  state.lastInterruptedStage ||= '';
  state.lastInterruptedAt ||= '';
  state.lastInterruptedPid ||= '';
  state.supersededArtifacts ||= [];
  state.stages = Array.isArray(state.stages) ? state.stages : [];
  return state;
}

function isProcessAlive(pid) {
  if (!pid || !/^[0-9]+$/.test(String(pid))) return false;
  try {
    process.kill(Number(pid), 0);
    return true;
  } catch {
    return false;
  }
}

function findStage(state, id) {
  return state.stages.find((item) => item.id === id);
}

function upsertStage(state, { id, label, status, message = '', taskId = '' }) {
  let stage = state.stages.find((item) => item.id === id);
  if (!stage) {
    stage = {
      id,
      label,
      taskId,
      epoch: Number(state.runEpoch || 0),
      reusePolicy: '',
      status: 'PENDING',
      startedAt: '',
      endedAt: '',
      message: '',
    };
    state.stages.push(stage);
  }

  stage.label = label || stage.label;
  stage.taskId = taskId || stage.taskId || '';
  stage.epoch = Number(opt('epoch', stage.epoch ?? state.runEpoch ?? 0));
  stage.reusePolicy = opt('reuse-policy', stage.reusePolicy || '');
  stage.status = status;
  stage.message = message;

  if (status === 'RUNNING') {
    const preservesActiveBlocker = state.status === 'blocked' && String(id || '').startsWith('blocked-report');
    stage.startedAt ||= nowIso();
    stage.endedAt = '';
    if (!preservesActiveBlocker) {
      state.status = 'running';
      state.currentStage = id;
      state.currentTask = taskId || '';
    }
  } else if (['DONE', 'FAILED', 'SKIPPED', 'BLOCKED', 'STOPPED', 'INTERRUPTED'].includes(status)) {
    stage.startedAt ||= nowIso();
    stage.endedAt = nowIso();
  }

  if (status === 'FAILED' || status === 'BLOCKED') {
    state.status = status === 'BLOCKED' ? 'blocked' : state.status;
    state.currentStage = id;
    state.currentTask = taskId || state.currentTask || '';
  }

  if (status === 'STOPPED') {
    state.status = 'stopped';
    state.currentStage = id;
    state.currentTask = taskId || state.currentTask || '';
  }

  if (status === 'INTERRUPTED') {
    state.status = 'interrupted';
    state.currentStage = id;
    state.currentTask = taskId || state.currentTask || '';
  }
}

function reconcileState(runDir, state) {
  let changed = false;
  if (state.currentPid && !isProcessAlive(state.currentPid)) {
    const interruptedAt = nowIso();
    const stageId = state.currentPidStage || state.currentStage;
    const stage = stageId ? findStage(state, stageId) : null;
    if (stage?.status === 'RUNNING') {
      stage.status = 'INTERRUPTED';
      stage.endedAt = interruptedAt;
      stage.message = `${stage.message || ''} interrupted; recorded pid ${state.currentPid} is not running`.trim();
      updateCheckpoint(runDir, stage);
    }
    state.lastInterruptedStage = stageId || state.lastInterruptedStage || '';
    state.lastInterruptedAt = interruptedAt;
    state.lastInterruptedPid = String(state.currentPid);
    state.currentPid = '';
    state.currentPidStage = '';
    state.status = 'interrupted';
    event(runDir, state, {
      eventType: 'interrupted',
      stage: stageId,
      label: stage?.label || stageId || 'unknown',
      message: `recorded pid ${state.lastInterruptedPid} is not running`,
      category: 'STALE_PID',
    });
    const progress = readJson(progressPath(runDir), null);
    if (progress && typeof progress === 'object') {
      progress.status = 'interrupted';
      progress.current_item = `interrupted at ${stageId || 'unknown stage'}`;
      progress.next_item = 'rerun the same harness command to resume';
      progress.last_update = interruptedAt;
      writeJson(progressPath(runDir), progress);
    }
    changed = true;
  }
  return changed;
}

function updateBlockedJson(runDir, fields) {
  const file = path.join(runDir, 'blocked.json');
  if (!fs.existsSync(file)) return;
  const value = readJson(file, null);
  if (!value || typeof value !== 'object') return;
  writeJson(file, { ...value, ...fields });
}

function resolveBlockedJsonOnDone(runDir) {
  const file = path.join(runDir, 'blocked.json');
  if (!fs.existsSync(file)) return;
  const value = readJson(file, null);
  if (!value || typeof value !== 'object') return;
  if (value.active === false && value.resolved === true) return;
  updateBlockedJson(runDir, {
    active: false,
    resolved: true,
    resolvedAt: value.resolvedAt || nowIso(),
    supersededBy: value.supersededBy || 'run completed',
  });
}

function resolveBlockedState(runDir, state, reason) {
  const hadBlocked = state.status === 'blocked' || state.blockedCategory || state.blockedReason;
  if (!hadBlocked) return false;
  const resolvedAt = nowIso();
  state.lastBlockedCategory = state.blockedCategory || state.lastBlockedCategory || '';
  state.lastBlockedReason = state.blockedReason || state.lastBlockedReason || '';
  state.lastBlockedAt = resolvedAt;
  state.blockedCategory = '';
  state.blockedReason = '';
  state.status = 'running';
  if (String(state.currentStage || '').startsWith('blocked')) {
    state.currentStage = '';
  }
  state.resumeCount = Number(state.resumeCount || 0) + 1;
  state.runEpoch = Number(state.runEpoch || 0) + 1;
  state.lastResumeAt = resolvedAt;
  updateBlockedJson(runDir, {
    active: false,
    resolved: true,
    resolvedAt,
    supersededBy: reason || 'resume',
  });
  event(runDir, state, {
    eventType: 'resume-after-blocked',
    stage: state.currentStage,
    label: state.currentStage || 'resume',
    message: reason || 'blocked condition cleared',
    category: state.lastBlockedCategory,
  });
  return true;
}

function writeStatus(runDir, state) {
  const progress = readJson(progressPath(runDir), {});
  const total = state.stages.length || 1;
  const lines = [];
  lines.push('# Harness Status');
  lines.push('');
  lines.push(`- Feature: ${state.feature || 'unknown'}`);
  lines.push(`- Status: ${state.status}`);
  lines.push(`- Current stage: ${state.currentStage || 'none'}`);
  lines.push(`- Current task: ${state.currentTask || 'none'}`);
  lines.push(`- Current PID: ${state.currentPid || 'none'}`);
  lines.push(`- Current PID stage: ${state.currentPidStage || 'none'}`);
  lines.push(`- Elapsed: ${fmt(secondsBetween(state.startedAt))}`);
  lines.push(`- Workspace: ${state.workspace || 'workspace'}`);
  lines.push(`- Live mode: ${state.liveMode || '0'}`);
  lines.push(`- Latest verify log: ${state.latestVerifyLog || 'none'}`);
  lines.push(`- Latest live log: ${state.latestLiveLog || 'none'}`);
  lines.push(`- Resume count: ${state.resumeCount || 0}`);
  lines.push(`- Run epoch: ${state.runEpoch || 0}`);
  lines.push(`- Last resume: ${state.lastResumeAt || 'none'}`);
  lines.push(`- Last interruption: ${state.lastInterruptedStage ? `${state.lastInterruptedStage} at ${state.lastInterruptedAt || 'unknown'}` : 'none'}`);
  lines.push('');
  lines.push('## Active Blocker');
  lines.push('');
  if (state.status === 'blocked') {
    lines.push(`- Category: ${state.blockedCategory || 'unknown'}`);
    lines.push(`- Reason: ${state.blockedReason || 'unknown'}`);
    lines.push(`- Stage: ${state.currentStage || 'unknown'}`);
  } else {
    lines.push('- Category: none');
    lines.push('- Reason: none');
    lines.push('- Stage: none');
  }
  lines.push('');
  lines.push('## Historical Blocks');
  lines.push('');
  lines.push(`- Last blocked category: ${state.lastBlockedCategory || 'none'}`);
  lines.push(`- Last blocked reason: ${state.lastBlockedReason || 'none'}`);
  lines.push(`- Last blocked resolved at: ${state.lastBlockedAt || 'none'}`);
  if (Array.isArray(state.supersededArtifacts) && state.supersededArtifacts.length > 0) {
    const latest = state.supersededArtifacts.slice(-5).map((item) => `${item.path} -> ${item.reason || 'superseded'}`);
    lines.push(`- Superseded artifacts: ${latest.join('; ')}`);
  }
  lines.push('');
  lines.push('## Steps');
  lines.push('');
  lines.push('| Step | Epoch | Policy | Status | Duration | Name | Detail |');
  lines.push('| --- | --- | --- | --- | --- | --- | --- |');
  state.stages.forEach((stage, index) => {
    const end = stage.endedAt || new Date();
    const duration = stage.startedAt ? fmt(secondsBetween(stage.startedAt, end)) : '00:00:00';
    const detail = (stage.message || '').replace(/\|/g, '/');
    const activeBlockedStage = state.status === 'blocked' && stage.id === state.currentStage && stage.status === 'BLOCKED';
    const displayStatus = stage.status === 'BLOCKED' && !activeBlockedStage ? 'BLOCKED(HISTORICAL)' : stage.status;
    lines.push(`| ${index + 1}/${total} | ${stage.epoch ?? 0} | ${stage.reusePolicy || ''} | ${displayStatus} | ${duration} | ${stage.label} | ${detail} |`);
  });
  if (state.stages.length === 0) {
    lines.push('| 0/0 | 0 | | PENDING | 00:00:00 | none | |');
  }
  lines.push('');
  lines.push('## Current Progress');
  lines.push('');
  lines.push(`- Task: ${progress.task_id || state.currentTask || 'none'}`);
  lines.push(`- Status: ${state.status === 'interrupted' && progress.status === 'running' ? 'interrupted' : progress.status || 'unknown'}`);
  lines.push(`- Current item: ${progress.current_item || 'none'}`);
  lines.push(`- Next item: ${progress.next_item || 'none'}`);
  lines.push(`- Last update: ${progress.last_update || 'none'}`);
  lines.push(`- Progress idle: ${progress.last_update ? fmt(secondsBetween(progress.last_update)) : 'unknown'}`);
  if (Array.isArray(progress.completed_items) && progress.completed_items.length > 0) {
    lines.push(`- Completed items: ${progress.completed_items.join('; ')}`);
  }
  lines.push('');
  lines.push('## Resume History');
  lines.push('');
  lines.push(`- Resume count: ${state.resumeCount || 0}`);
  lines.push(`- Run epoch: ${state.runEpoch || 0}`);
  lines.push(`- Last resume: ${state.lastResumeAt || 'none'}`);
  lines.push(`- Last interruption stage: ${state.lastInterruptedStage || 'none'}`);
  lines.push(`- Last interruption at: ${state.lastInterruptedAt || 'none'}`);
  lines.push(`- Last interrupted PID: ${state.lastInterruptedPid || 'none'}`);
  lines.push(`- Last blocked category: ${state.lastBlockedCategory || 'none'}`);
  lines.push(`- Last blocked reason: ${state.lastBlockedReason || 'none'}`);
  lines.push('');
  lines.push('## Logs');
  const files = fs.existsSync(runDir)
    ? fs.readdirSync(runDir)
        .filter((name) => /\.(log|md|json|yaml)$/.test(name))
        .sort()
    : [];
  for (const file of files) {
    lines.push(`- ${path.join(runDir, file)}`);
  }
  fs.writeFileSync(statusPath(runDir), `${lines.join('\n')}\n`);
}

function printStatus(runDir, state) {
  writeStatus(runDir, state);
  const content = fs.readFileSync(statusPath(runDir), 'utf8');
  const lines = content.split('\n');
  const end = lines.findIndex((line) => line === '## Logs');
  console.log(lines.slice(0, end === -1 ? lines.length : end).join('\n').trimEnd());
}

function printSummary(runDir, state) {
  writeStatus(runDir, state);
  const progress = readJson(progressPath(runDir), {});
  const total = state.stages.length || 0;
  const done = state.stages.filter((stage) => stage.status === 'DONE' || stage.status === 'SKIPPED').length;
  const running = state.stages.find((stage) => stage.status === 'RUNNING');
  const activeBlocked = state.status === 'blocked'
    ? state.stages.find((stage) => stage.id === state.currentStage && (stage.status === 'FAILED' || stage.status === 'BLOCKED' || stage.status === 'STOPPED'))
    : null;
  const current = running || activeBlocked || state.stages[state.stages.length - 1];
  const currentIndex = current ? state.stages.findIndex((stage) => stage.id === current.id) + 1 : 0;
  const duration = current?.startedAt ? fmt(secondsBetween(current.startedAt, current.endedAt || new Date())) : '00:00:00';
  const progressIdle = progress.last_update ? fmt(secondsBetween(progress.last_update)) : 'unknown';
  console.log(`[harness] status=${state.status} step=${currentIndex}/${total} done=${done}/${total} current=${current?.id || 'none'} stage_status=${current?.status || 'none'} duration=${duration} pid=${state.currentPid || 'none'} progress_idle=${progressIdle}`);
  if (current?.message) {
    console.log(`[harness] detail=${current.message}`);
  }
}

function event(runDir, state, { eventType, stage = '', label = '', message = '', category = '' }) {
  appendJsonl(timelinePath(runDir), {
    time: nowIso(),
    event: eventType,
    stage,
    label,
    message,
    category,
    elapsed: fmt(secondsBetween(state.startedAt)),
  });
}

if (command === 'init') {
  const runDir = opt('run-dir');
  const fresh = hasFlag('fresh');
  const existing = fresh ? null : readJson(statePath(runDir), null);
  const state = normalizeState(existing ?? {
    feature: opt('feature'),
    status: 'running',
    workspace: opt('workspace', 'workspace'),
    liveMode: opt('live', '0'),
    startedAt: nowIso(),
    updatedAt: nowIso(),
    currentStage: '',
    currentTask: '',
    blockedCategory: '',
    blockedReason: '',
    latestVerifyLog: '',
    latestLiveLog: '',
    currentPid: '',
    currentPidStage: '',
    runEpoch: 0,
    stages: [],
  });
  state.feature = opt('feature', state.feature);
  state.workspace = opt('workspace', state.workspace || 'workspace');
  state.liveMode = opt('live', state.liveMode || '0');
  state.status = state.status === 'done' ? 'done' : 'running';
  fs.mkdirSync(runDir, { recursive: true });
  writeJson(checkpointPath(runDir), readJson(checkpointPath(runDir), { stages: {} }));
  saveState(runDir, state);
  process.exit(0);
}

if (command === 'reconcile') {
  const runDir = opt('run-dir');
  const state = loadState(runDir);
  const changed = reconcileState(runDir, state);
  saveState(runDir, state);
  process.exit(changed ? 10 : 0);
}

if (command === 'resolve-blocked') {
  const runDir = opt('run-dir');
  const state = loadState(runDir);
  const changed = resolveBlockedState(runDir, state, opt('reason', 'resume'));
  saveState(runDir, state);
  process.exit(changed ? 10 : 0);
}

if (command === 'mark-superseded') {
  const runDir = opt('run-dir');
  const state = loadState(runDir);
  const artifactPath = opt('path');
  const reason = opt('reason', 'superseded');
  if (artifactPath) {
    state.supersededArtifacts.push({
      path: artifactPath,
      reason,
      time: nowIso(),
    });
    event(runDir, state, {
      eventType: 'artifact-superseded',
      stage: opt('stage', state.currentStage),
      label: artifactPath,
      message: reason,
      category: '',
    });
  }
  saveState(runDir, state);
  process.exit(0);
}

if (command === 'stage') {
  const runDir = opt('run-dir');
  const state = loadState(runDir);
  const id = opt('id');
  const label = opt('label', id);
  const status = opt('status', 'RUNNING');
  const message = opt('message', '');
  const taskId = opt('task-id', '');
  upsertStage(state, { id, label, status, message, taskId });
  if (status === 'BLOCKED') {
    state.status = 'blocked';
    state.blockedCategory = opt('category', state.blockedCategory);
    state.blockedReason = message || state.blockedReason;
  }
  updateCheckpoint(runDir, state.stages.find((item) => item.id === id));
  event(runDir, state, { eventType: status.toLowerCase(), stage: id, label, message, category: opt('category', '') });
  saveState(runDir, state);
  if (hasFlag('print')) printStatus(runDir, state);
  process.exit(0);
}

if (command === 'meta') {
  const runDir = opt('run-dir');
  const state = loadState(runDir);
  for (let index = 0; index < args.length; index += 1) {
    const item = args[index];
    if (!item.startsWith('--')) continue;
    const key = item.slice(2);
    const value = args[index + 1] ?? '';
    if (key === 'run-dir') {
      index += 1;
      continue;
    }
    state[key] = value;
    index += 1;
  }
  if (state.status === 'done') {
    state.blockedCategory = '';
    state.blockedReason = '';
    resolveBlockedJsonOnDone(runDir);
  }
  saveState(runDir, state);
  process.exit(0);
}

if (command === 'event') {
  const runDir = opt('run-dir');
  const state = loadState(runDir);
  event(runDir, state, {
    eventType: opt('event', 'info'),
    stage: opt('stage'),
    label: opt('label'),
    message: opt('message'),
    category: opt('category'),
  });
  saveState(runDir, state);
  process.exit(0);
}

if (command === 'progress') {
  const runDir = opt('run-dir');
  const progress = {
    feature: opt('feature'),
    stage: opt('stage'),
    task_id: opt('task-id'),
    status: opt('status', 'running'),
    completed_items: [],
    current_item: opt('current-item', ''),
    next_item: opt('next-item', ''),
    last_update: nowIso(),
  };
  writeJson(progressPath(runDir), progress);
  if (fs.existsSync(statePath(runDir))) {
    writeStatus(runDir, loadState(runDir));
  }
  process.exit(0);
}

if (command === 'done?') {
  const runDir = opt('run-dir');
  const id = opt('id');
  const state = loadState(runDir);
  const stage = state.stages.find((item) => item.id === id);
  process.exit(stage?.status === 'DONE' ? 0 : 1);
}

if (command === 'render') {
  const runDir = opt('run-dir');
  const state = loadState(runDir);
  if (hasFlag('print')) printStatus(runDir, state);
  else writeStatus(runDir, state);
  process.exit(0);
}

if (command === 'summary') {
  const runDir = opt('run-dir');
  const state = loadState(runDir);
  printSummary(runDir, state);
  process.exit(0);
}

if (command === 'sort') {
  const runDir = opt('run-dir');
  const state = loadState(runDir);
  state.stages.sort((a, b) => statusRank(a.status) - statusRank(b.status));
  saveState(runDir, state);
  process.exit(0);
}

console.error(`Unknown command: ${command || '<none>'}`);
process.exit(2);
