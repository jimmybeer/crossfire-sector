#!/usr/bin/env node
/**
 * Stage 1: build UI reference export for glossary panels.
 * Sources: fixtures in docs/data-definition/fixtures (factions, missions, commander traits, battle events)
 * plus action summaries from rules.md. Includes per-round deltas, localization placeholders, and requirement IDs.
 */

const fs = require("fs");
const path = require("path");

const ROOT = path.join(__dirname, "..");
const OUTPUT = path.join(ROOT, "docs", "data-definition", "exports", "ui_reference.json");
const FIXTURES = {
  factions: path.join(ROOT, "docs", "data-definition", "fixtures", "factions.json"),
  missions: path.join(ROOT, "docs", "data-definition", "fixtures", "missions.json"),
  commander_traits: path.join(ROOT, "docs", "data-definition", "fixtures", "commander_traits.json"),
  battle_events: path.join(ROOT, "docs", "data-definition", "fixtures", "battle_events.json"),
};

function readJson(p) {
  return JSON.parse(fs.readFileSync(p, "utf8"));
}

function actionList() {
  return [
    {
      id: "move",
      name: "Move",
      description: "Move up to Move stat; diagonals allowed unless blocked by terrain corners.",
      requirements: ["GR-017", "GR-018", "DA-004"],
    },
    {
      id: "attack",
      name: "Attack",
      description: "Half move (rounded up) then Shoot; check Range/LoS/Cover.",
      requirements: ["GR-019", "GR-021.1", "GR-022", "DA-005", "DA-012"],
    },
    {
      id: "melee",
      name: "Melee",
      description: "Half move (rounded up) then adjacent melee roll.",
      requirements: ["GR-019", "GR-027", "DA-012"],
    },
    {
      id: "first_aid",
      name: "First Aid",
      description: "Half move (rounded up) then aid adjacent Down unit; stand up and may activate if budget remains.",
      requirements: ["GR-020", "GR-029", "DA-007"],
    },
    {
      id: "hold",
      name: "Hold Position",
      description: "Do nothing; preserves activation; used for demo smoke.",
      requirements: ["GR-021"],
    },
  ];
}

function factionList() {
  const data = readJson(FIXTURES.factions);
  return data.map((f) => {
    const reqs = ["GR-005", "GR-007"];
    if (f.id === "azure_blades") reqs.push("GR-008");
    if (f.id === "grey_cloaks") reqs.push("GR-009");
    if (f.id === "solar_wardens") reqs.push("GR-010", "GR-011");
    return {
      id: f.id,
      name: f.name,
      stats: {
        move: f.base_stats.move,
        range: f.base_stats.range,
        aq: f.base_stats.aq,
        defense: f.base_stats.defense,
      },
      notes: traitNotes(f.traits),
      requirements: reqs,
    };
  });
}

function traitNotes(traits = []) {
  if (traits.includes("azure_melee_aq_bonus")) return "Melee AQ +2 (replaces +1).";
  if (traits.includes("grey_reroll")) return "Reroll one attack die (ranged/melee), keep chosen result.";
  if (traits.includes("solar_deadly_rounds")) return "Natural 11/12 instant kill (before AQ).";
  return "";
}

function missionList() {
  const data = readJson(FIXTURES.missions);
  return data.map((m) => {
    const reqs = ["GR-033", "GR-035", "DA-008", "DA-009", "DA-016"];
    const summary = m.notes || "";
    const scoring = scoringText(m.scoring_rules || {});
    const perRound = perRoundDeltas(m);
    return {
      id: m.id,
      name: m.name,
      summary,
      scoring,
      per_round_deltas: perRound,
      requirements: reqs,
    };
  });
}

function scoringText(scoringRules) {
  if (!scoringRules || !scoringRules.points) return "";
  const points = scoringRules.points;
  if (points.kill) return "Per-round: +1 per kill; most points wins after round limit.";
  if (points.control) {
    const bonus = points.nearest_opponent_bonus ? `; +${points.nearest_opponent_bonus} nearest opponent` : "";
    const b = points.control;
    return `Per-round: +${b} per control${bonus}.`;
  }
  if (points.deny) return "Per-round: prevent enemy in zone for +1.";
  if (points.home_zone_presence) return "Per-round: +1 for more units in opponent home zone.";
  return "";
}

function perRoundDeltas(mission) {
  if (mission.id === "crossfire_clash") return ["+1 per kill each round"];
  if (mission.id === "control_center") return ["+1 per round for most units in center band"];
  if (mission.id === "break_through") return ["+1 per round for more units in opponent home zone"];
  if (mission.id === "dead_center") return ["+1 per round for controlling center point"];
  if (mission.id === "dead_zone") return ["+1 per round if enemy absent from center band"];
  if (mission.id === "occupy") return ["+1 per sector controlled; +1 sector B; +3 nearest opponent sector"];
  return [];
}

function commanderTraits() {
  const data = readJson(FIXTURES.commander_traits);
  return data.map((t) => {
    const reqs = ["GR-041", "DA-020"];
    return { id: t.id, name: t.name, effect: t.effect, requirements: reqs };
  });
}

function battleEvents() {
  const data = readJson(FIXTURES.battle_events);
  return data.map((e) => {
    const reqs = ["GR-042", "DA-019", "DA-020"];
    return { id: e.id, name: e.name, effect: e.effect, requirements: reqs };
  });
}

function buildReference() {
  return {
    version: "1.0.0",
    generated_at: new Date().toISOString(),
    factions: factionList(),
    actions: actionList(),
    missions: missionList(),
    optional_rules: {
      commander_traits: commanderTraits(),
      battle_events: battleEvents(),
    },
    glossary: [],
  };
}

fs.writeFileSync(OUTPUT, JSON.stringify(buildReference(), null, 2));
console.log(`[build-ui-reference] wrote ${OUTPUT}`);
