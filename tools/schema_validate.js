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
  "docs/data-definition/exports/ui_reference.json",
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

function validateUIReference() {
  const data = readJson(FIXTURES[4]);
  if (!data) return;
  if (typeof data.version !== "string") errors.push("ui_reference.version missing/string");
  ["factions", "actions", "missions"].forEach((key) => {
    if (!Array.isArray(data[key])) errors.push(`ui_reference.${key} missing/array`);
  });
  const optionalRules = data.optional_rules || {};
  if (!Array.isArray(optionalRules.commander_traits || []))
    errors.push("ui_reference.optional_rules.commander_traits missing/array");
  if (!Array.isArray(optionalRules.battle_events || []))
    errors.push("ui_reference.optional_rules.battle_events missing/array");
  const gloss = data.glossary;
  if (gloss && !Array.isArray(gloss)) errors.push("ui_reference.glossary must be array if present");
  const validateEntry = (entry, source) => {
    if (typeof entry.id !== "string") errors.push(`${source}.id missing/string`);
    if (typeof entry.name !== "string" && typeof entry.title !== "string")
      errors.push(`${source}.name/title missing/string`);
    if (entry.requirements && !Array.isArray(entry.requirements))
      errors.push(`${source}.requirements must be array when present`);
    if (entry.per_round_deltas && !Array.isArray(entry.per_round_deltas))
      errors.push(`${source}.per_round_deltas must be array when present`);
  };
  data.factions?.forEach((e, idx) => validateEntry(e, `ui_reference.factions[${idx}]`));
  data.actions?.forEach((e, idx) => validateEntry(e, `ui_reference.actions[${idx}]`));
  data.missions?.forEach((e, idx) => validateEntry(e, `ui_reference.missions[${idx}]`));
  optionalRules.commander_traits?.forEach((e, idx) =>
    validateEntry(e, `ui_reference.optional_rules.commander_traits[${idx}]`)
  );
  optionalRules.battle_events?.forEach((e, idx) =>
    validateEntry(e, `ui_reference.optional_rules.battle_events[${idx}]`)
  );
  gloss?.forEach((e, idx) => validateEntry(e, `ui_reference.glossary[${idx}]`));
}

validateSaveMatch();
validateCommandLogFixture();
validateMatchState();
validateCommandsList();
validateUIReference();

if (errors.length) {
  console.error("[schema-validate] FAIL");
  errors.forEach((e) => console.error(" -", e));
  process.exit(1);
}

console.log("[schema-validate] PASS");
