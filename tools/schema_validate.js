#!/usr/bin/env node
/**
 * Lightweight schema validation for Stage 0 fixtures.
 */

const fs = require("fs");
const path = require("path");

const FIXTURES = [
  "docs/data-definition/fixtures/save_match.json",
  "docs/data-definition/fixtures/command_log.json",
  "docs/data-definition/fixtures/match_state.json",
  "docs/data-definition/fixtures/commands.json",
];

const errors = [];

function readJson(p) {
  try {
    return JSON.parse(fs.readFileSync(p, "utf8"));
  } catch (e) {
    errors.push(`Failed to read ${p}: ${e.message}`);
    return null;
  }
}

function hasPrefix(value, prefix) {
  return typeof value === "string" && value.startsWith(prefix);
}

function validateCommand(cmd, idx, source) {
  if (typeof cmd.id !== "string") errors.push(`${source}[${idx}].id missing`);
  if (typeof cmd.sequence !== "number") errors.push(`${source}[${idx}].sequence missing/number`);
  if (typeof cmd.type !== "string") errors.push(`${source}[${idx}].type missing`);
  if (typeof cmd.rng_offset_before !== "number")
    errors.push(`${source}[${idx}].rng_offset_before missing/number`);
  if (!hasPrefix(cmd.state_hash_after, "sha256:"))
    errors.push(`${source}[${idx}].state_hash_after missing sha256 prefix`);
}

function validateCommandLog(log, source) {
  if (!Array.isArray(log.entries) || log.entries.length === 0)
    errors.push(`${source}.entries missing/empty`);
  if (!hasPrefix(log.checksum, "sha256:"))
    errors.push(`${source}.checksum missing sha256 prefix`);
  log.entries?.forEach((cmd, idx) => validateCommand(cmd, idx, `${source}.entries`));
}

function validateSaveMatch() {
  const data = readJson(FIXTURES[0]);
  if (!data || !data.match) return;
  const match = data.match;
  if (!hasPrefix(match.state_hash, "sha256:"))
    errors.push("save_match.match.state_hash missing sha256 prefix");
  if (!match.rng || typeof match.rng.seed === "undefined")
    errors.push("save_match.match.rng missing seed");
  validateCommandLog(match.command_log || {}, "save_match.match.command_log");
  if (!data.meta || !hasPrefix(data.meta.checksum, "sha256:"))
    errors.push("save_match.meta.checksum missing sha256 prefix");
}

function validateCommandLogFixture() {
  const data = readJson(FIXTURES[1]);
  if (!data) return;
  validateCommandLog(data, "command_log");
}

function validateMatchState() {
  const data = readJson(FIXTURES[2]);
  if (!data) return;
  if (!hasPrefix(data.state_hash, "sha256:"))
    errors.push("match_state.state_hash missing sha256 prefix");
}

function validateCommandsList() {
  const data = readJson(FIXTURES[3]);
  if (!Array.isArray(data)) {
    errors.push("commands.json must be an array");
    return;
  }
  data.forEach((cmd, idx) => validateCommand(cmd, idx, "commands"));
}

validateSaveMatch();
validateCommandLogFixture();
validateMatchState();
validateCommandsList();

if (errors.length) {
  console.error("[schema-validate] FAIL");
  errors.forEach((e) => console.error(" -", e));
  process.exit(1);
}

console.log("[schema-validate] PASS");
