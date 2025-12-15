#!/usr/bin/env node
/**
 * Lightweight schema validation for Stage 0 fixtures.
 */

const fs = require("fs");
const path = require("path");

const FIXTURES = {
  save_match: "docs/data-definition/fixtures/save_match.json",
  command_log: "docs/data-definition/fixtures/command_log.json",
  match_state: "docs/data-definition/fixtures/match_state.json",
  match_state_crossfire: "docs/data-definition/fixtures/match_state_crossfire_clash.json",
  match_state_dead_zone: "docs/data-definition/fixtures/match_state_dead_zone.json",
  match_state_occupy: "docs/data-definition/fixtures/match_state_occupy.json",
  commands: "docs/data-definition/fixtures/commands.json",
  optional_rules: "docs/data-definition/fixtures/optional_rules_config.json",
  factions: "docs/data-definition/fixtures/factions.json",
  missions: "docs/data-definition/fixtures/missions.json",
  terrain_templates: "docs/data-definition/fixtures/terrain_templates.json",
  commander_traits: "docs/data-definition/fixtures/commander_traits.json",
  battle_events: "docs/data-definition/fixtures/battle_events.json",
  advantages: "docs/data-definition/fixtures/advantages.json",
  rng_seed: "docs/data-definition/fixtures/rng_seed.json",
  ui_reference: "docs/data-definition/exports/ui_reference.json",
};

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
  const data = readJson(FIXTURES.save_match);
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
  const data = readJson(FIXTURES.command_log);
  if (!data) return;
  validateCommandLog(data, "command_log");
}

function validateMatchState(label, fixturePath) {
  const data = readJson(fixturePath);
  if (!data) return;
  if (!hasPrefix(data.state_hash, "sha256:"))
    errors.push(`${label}.state_hash missing sha256 prefix`);
  const optional = data.optional_rules || {};
  ["commander", "events", "campaign"].forEach((flag) => {
    if (typeof optional[flag] !== "boolean")
      errors.push(`${label}.optional_rules.${flag} missing/boolean`);
  });
}

function validateCommandsList() {
  const data = readJson(FIXTURES.commands);
  if (!Array.isArray(data)) {
    errors.push("commands.json must be an array");
    return;
  }
  data.forEach((cmd, idx) => validateCommand(cmd, idx, "commands"));
}

function validateUIReference() {
  const data = readJson(FIXTURES.ui_reference);
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

function validateOptionalRules() {
  const data = readJson(FIXTURES.optional_rules);
  if (!data) return;
  ["commander", "events", "campaign"].forEach((key) => {
    if (typeof data[key] !== "boolean") errors.push(`optional_rules.${key} must be boolean`);
  });
  ["commander", "events", "campaign"].forEach((key) => {
    if (data[key] !== false) errors.push(`optional_rules.${key} must default to false`);
  });
  if (typeof data.version !== "string") errors.push("optional_rules.version missing/string");
}

function validateFactions() {
  const data = readJson(FIXTURES.factions);
  if (!Array.isArray(data)) {
    errors.push("factions.json must be an array");
    return;
  }
  data.forEach((fac, idx) => {
    const prefix = `factions[${idx}]`;
    if (typeof fac.id !== "string") errors.push(`${prefix}.id missing/string`);
    if (typeof fac.name !== "string") errors.push(`${prefix}.name missing/string`);
    if (typeof fac.roster_limit !== "number") errors.push(`${prefix}.roster_limit missing/number`);
    if (typeof fac.movement_mode !== "string") errors.push(`${prefix}.movement_mode missing/string`);
    if (!Array.isArray(fac.traits)) errors.push(`${prefix}.traits missing/array`);
    if (typeof fac.version !== "string") errors.push(`${prefix}.version missing/string`);
    const base = fac.base_stats || {};
    ["range", "aq", "defense"].forEach((stat) => {
      if (typeof base[stat] !== "number") errors.push(`${prefix}.base_stats.${stat} missing/number`);
    });
    if (typeof base.move !== "number" && typeof base.move !== "string")
      errors.push(`${prefix}.base_stats.move must be number or dice string`);
  });
}

function validateMissions() {
  const data = readJson(FIXTURES.missions);
  if (!Array.isArray(data)) return;
  data.forEach((mis, idx) => {
    const prefix = `missions[${idx}]`;
    if (typeof mis.id !== "string") errors.push(`${prefix}.id missing/string`);
    if (typeof mis.name !== "string") errors.push(`${prefix}.name missing/string`);
    if (!Array.isArray(mis.control_zones)) errors.push(`${prefix}.control_zones missing/array`);
    if (typeof mis.scoring_rules !== "object") errors.push(`${prefix}.scoring_rules missing/object`);
    if (typeof mis.round_limit !== "number") errors.push(`${prefix}.round_limit missing/number`);
    if (typeof mis.max_extra_rounds !== "number")
      errors.push(`${prefix}.max_extra_rounds missing/number`);
    if (typeof mis.unique_per_campaign !== "boolean")
      errors.push(`${prefix}.unique_per_campaign missing/boolean`);
    if (typeof mis.version !== "string") errors.push(`${prefix}.version missing/string`);
  });
}

function validateTerrainTemplates() {
  const data = readJson(FIXTURES.terrain_templates);
  if (!Array.isArray(data)) return;
  data.forEach((ter, idx) => {
    const prefix = `terrain_templates[${idx}]`;
    if (typeof ter.id !== "string") errors.push(`${prefix}.id missing/string`);
    if (typeof ter.name !== "string") errors.push(`${prefix}.name missing/string`);
    const size = ter.size_range || {};
    if (typeof size.min !== "number") errors.push(`${prefix}.size_range.min missing/number`);
    if (typeof size.max !== "number") errors.push(`${prefix}.size_range.max missing/number`);
    ["blocks_los", "provides_cover", "impassable"].forEach((flag) => {
      if (typeof ter[flag] !== "boolean") errors.push(`${prefix}.${flag} must be boolean`);
    });
    if (typeof ter.placement_weight !== "number")
      errors.push(`${prefix}.placement_weight missing/number`);
    if (typeof ter.version !== "string") errors.push(`${prefix}.version missing/string`);
  });
}

function validateSimpleList(fixturePath, label, fields) {
  const data = readJson(fixturePath);
  if (!Array.isArray(data)) return;
  data.forEach((entry, idx) => {
    const prefix = `${label}[${idx}]`;
    fields.forEach((field) => {
      if (typeof entry[field] !== "string") errors.push(`${prefix}.${field} missing/string`);
    });
    if (typeof entry.version !== "string") errors.push(`${prefix}.version missing/string`);
  });
}

function validateRngSeed() {
  const data = readJson(FIXTURES.rng_seed);
  if (!data) return;
  if (typeof data.seed !== "string") errors.push("rng_seed.seed missing/string");
  if (typeof data.offset !== "number") errors.push("rng_seed.offset missing/number");
  if (typeof data.version !== "string") errors.push("rng_seed.version missing/string");
}

validateSaveMatch();
validateCommandLogFixture();
validateMatchState("match_state", FIXTURES.match_state);
validateMatchState("match_state_crossfire_clash", FIXTURES.match_state_crossfire);
validateMatchState("match_state_dead_zone", FIXTURES.match_state_dead_zone);
validateMatchState("match_state_occupy", FIXTURES.match_state_occupy);
validateCommandsList();
validateOptionalRules();
validateFactions();
validateMissions();
validateTerrainTemplates();
validateSimpleList(FIXTURES.commander_traits, "commander_traits", ["id", "name", "effect"]);
validateSimpleList(FIXTURES.battle_events, "battle_events", ["id", "name", "effect"]);
validateSimpleList(FIXTURES.advantages, "advantages", ["id", "name", "effect"]);
validateRngSeed();
validateUIReference();

if (errors.length) {
  console.error("[schema-validate] FAIL");
  errors.forEach((e) => console.error(" -", e));
  process.exit(1);
}

console.log("[schema-validate] PASS");
