#!/usr/bin/env node
/**
 * Stage 1: build UI reference export for glossary panels.
 * Source of truth is currently the inline data below; replace with parsed tables
 * from docs/data-definition/data-dictionary.md and rules.md in later stages.
 */

const fs = require("fs");
const path = require("path");

const OUTPUT = path.join(__dirname, "..", "docs", "data-definition", "exports", "ui_reference.json");

const reference = {
  version: "0.1.0",
  factions: [
    {
      id: "verdant_eye",
      name: "Verdant Eye",
      stats: { move: 4, range: 5, aq: 1, defense: 7 },
      requirements: ["GR-005", "GR-007"],
    },
    {
      id: "azure_blades",
      name: "Azure Blades",
      stats: { move: 5, range: 2, aq: 1, defense: 8 },
      notes: "Melee AQ +2",
      requirements: ["GR-005", "GR-007", "GR-008"],
    },
    {
      id: "ember_guard",
      name: "Ember Guard",
      stats: { move: 2, range: 3, aq: 2, defense: 9 },
      requirements: ["GR-005", "GR-007"],
    },
    {
      id: "grey_cloaks",
      name: "Grey Cloaks",
      stats: { move: 4, range: 3, aq: 0, defense: 8 },
      notes: "Reroll ranged/melee one die",
      requirements: ["GR-005", "GR-007", "GR-009"],
    },
    {
      id: "solar_wardens",
      name: "Solar Wardens",
      stats: { move: "d6", range: 4, aq: 1, defense: 9 },
      notes: "Deadly Rounds on natural 11/12",
      requirements: ["GR-005", "GR-007", "GR-010", "GR-011"],
    },
  ],
  actions: [
    { id: "move", name: "Move", description: "Move up to Move stat", requirements: ["GR-017", "GR-018"] },
    { id: "attack", name: "Attack", description: "Half move then Shoot", requirements: ["GR-019", "GR-022"] },
    { id: "melee", name: "Melee", description: "Adjacent melee roll", requirements: ["GR-019", "GR-027"] },
    { id: "first_aid", name: "First Aid", description: "Half move then aid adjacent Down unit", requirements: ["GR-020", "GR-029"] },
    { id: "hold", name: "Hold Position", description: "Do nothing", requirements: ["GR-021"] },
  ],
  missions: [
    { id: "crossfire_clash", name: "Crossfire Clash", requirements: ["GR-033"] },
    { id: "control_center", name: "Control Center", requirements: ["GR-033"] },
    { id: "break_through", name: "Break Through", requirements: ["GR-033"] },
    { id: "dead_center", name: "Dead Center", requirements: ["GR-033"] },
    { id: "dead_zone", name: "Dead Zone", requirements: ["GR-033"] },
    { id: "occupy", name: "Occupy", requirements: ["GR-033"] },
  ],
  optional_rules: {
    commander_traits: [
      { id: "resilient", name: "Resilient", requirements: ["GR-041"] },
      { id: "sniper", name: "Sniper", requirements: ["GR-041"] },
      { id: "stealth", name: "Stealth", requirements: ["GR-041", "DA-020"] },
    ],
    battle_events: [
      { id: "fog_of_war", name: "Fog of War", requirements: ["GR-042"] },
      { id: "deadly_rounds", name: "Deadly Rounds", requirements: ["GR-042"] },
      { id: "fast_assault", name: "Fast Assault", requirements: ["GR-042"] },
      { id: "focused_fire", name: "Focused Fire", requirements: ["GR-042"] },
      { id: "revive", name: "Revive", requirements: ["GR-042", "DA-019"] },
      { id: "no_events", name: "No Events", requirements: ["GR-042"] },
    ],
  },
};

fs.writeFileSync(OUTPUT, JSON.stringify(reference, null, 2));
console.log(`[build-ui-reference] wrote ${OUTPUT}`);
