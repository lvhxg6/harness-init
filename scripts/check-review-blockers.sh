#!/usr/bin/env bash
set -euo pipefail

review_file="${1:-}"
[[ -n "$review_file" && -f "$review_file" ]] || { echo "Usage: $0 <review-file>" >&2; exit 2; }

live_mode="${HARNESS_LIVE:-0}"
blockers_file="${review_file%.md}.blockers"
pending_file="${review_file%.md}.pending"

: > "$blockers_file"
: > "$pending_file"

node - "$review_file" "$live_mode" "$blockers_file" "$pending_file" <<'NODE'
const fs = require('node:fs');

const [reviewFile, liveMode, blockersFile, pendingFile] = process.argv.slice(2);
const text = fs.readFileSync(reviewFile, 'utf8');
const lines = text.split(/\r?\n/);

const severityStart = /^\s*(?:[-*]\s*)?(?:\*\*)?Severity(?:\*\*)?\s*[:：=]/i;
const severityStartZh = /^\s*(?:[-*]\s*)?(?:\*\*)?严重程度(?:\*\*)?\s*[:：=]/i;
const fieldNames = new Set([
  'severity',
  '严重程度',
  'category',
  '分类',
  'blocks stable',
  'blocks live',
  '阻断 stable',
  '阻断 live',
]);

function normalizeRecord(record) {
  return record.trim().replace(/\n{3,}/g, '\n\n');
}

function normalizeValue(value) {
  return String(value || '')
    .replace(/[`*_]+/g, '')
    .replace(/[.,;，。；].*$/, '')
    .trim()
    .toLowerCase();
}

function parseField(line) {
  const clean = line
    .replace(/^\s*(?:[-*]\s*)?/, '')
    .replace(/\*\*/g, '')
    .trim();
  const match = clean.match(/^([^:=：]+?)\s*[:：=]\s*(.*?)\s*$/);
  if (!match) return null;
  const key = match[1].trim().toLowerCase();
  if (!fieldNames.has(key)) return null;
  return { key, value: normalizeValue(match[2]) };
}

function fieldsOf(record) {
  const fields = {};
  for (const line of record.split(/\r?\n/)) {
    const parsed = parseField(line);
    if (!parsed) continue;
    fields[parsed.key] = parsed.value;
  }
  return fields;
}

function yesNo(value) {
  if (/^(yes|true|block|blocking|1|是|阻断)\b/i.test(value)) return 'yes';
  if (/^(no|false|allow|nonblocking|0|否|不阻断)\b/i.test(value)) return 'no';
  return '';
}

const records = [];
let current = [];
for (const line of lines) {
  if (severityStart.test(line) || severityStartZh.test(line)) {
    if (current.length > 0) {
      records.push(current.join('\n'));
    }
    current = [line];
  } else if (current.length > 0) {
    const parsed = parseField(line);
    const looksLikeNewFinding = /^\s*(?:[-*]\s*)?(?:\*\*)?(?:Feature|Requirement ids|Changed files|Commands run|Verification status|Known risks|审查结论|验证状态|已实现需求|变更文件|命令|风险)(?:\*\*)?\s*[:：]?/i.test(line);
    if (looksLikeNewFinding && !parsed) {
      records.push(current.join('\n'));
      current = [];
    } else {
      current.push(line);
    }
  } else {
    // Ignore prose before the first structured Severity block. This prevents
    // summaries such as "未发现 High、Medium 或 Live Pending 阻断项" from
    // becoming synthetic findings.
  }
}
if (current.length > 0) records.push(current.join('\n'));

const blockers = [];
const pending = [];

for (const rawRecord of records) {
  const record = normalizeRecord(rawRecord);
  if (!record) continue;

  const fields = fieldsOf(record);
  const severity = fields.severity || fields['严重程度'] || '';
  const category = fields.category || fields['分类'] || '';
  const highOrMedium = /^(high|medium|高|中)\b/i.test(severity);
  const livePending = /^live pending\b/i.test(severity);
  if (!highOrMedium && !livePending) continue;

  let blocksStable = yesNo(fields['blocks stable'] || fields['阻断 stable'] || '');
  let blocksLive = yesNo(fields['blocks live'] || fields['阻断 live'] || '');

  if (!blocksStable && (livePending || category === 'live-only')) blocksStable = 'no';
  if (!blocksLive && (livePending || category === 'live-only')) blocksLive = 'yes';
  if (!blocksStable && highOrMedium) blocksStable = 'yes';
  if (!blocksLive && highOrMedium) blocksLive = 'yes';

  const shouldBlock = liveMode === '1' ? blocksLive === 'yes' : blocksStable === 'yes';
  const entry = record.includes('\n') ? `${record}\n` : record;

  if (shouldBlock) {
    blockers.push(entry);
  } else if (livePending || category === 'live-only' || blocksLive === 'yes') {
    pending.push(entry);
  }
}

if (blockers.length > 0) {
  fs.writeFileSync(blockersFile, `${blockers.join('\n---\n')}\n`);
}
if (pending.length > 0) {
  fs.writeFileSync(pendingFile, `${pending.join('\n---\n')}\n`);
}

console.log(`[review-gate] Mode: ${liveMode === '1' ? 'live' : 'stable'}`);
if (pending.length > 0) {
  console.log(`[review-gate] Pending non-blocking findings: ${pendingFile}`);
}
if (blockers.length > 0) {
  console.error(`[review-gate] Blocking review findings detected in ${reviewFile}`);
  console.error(fs.readFileSync(blockersFile, 'utf8').trimEnd());
  process.exit(1);
}

console.log('[review-gate] No blocking review findings');
NODE
