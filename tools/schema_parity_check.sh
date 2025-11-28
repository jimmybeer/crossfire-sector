#!/usr/bin/env bash
# Schema parity check for Stage 0 fixtures
# Validates JSON fixtures for core entities against minimal shape checks derived
# from docs/data-definition/data-dictionary.md (factions, missions, terrain,
# optional rules, match/campaign state, RNGSeed, Command, CommandLog).

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fixtures="$repo_root/docs/data-definition/fixtures"
cd "$repo_root"

python3 - <<'PY'
import json
import sys
from pathlib import Path

fixtures = Path("docs/data-definition/fixtures")
allowed_command_types = {
    "deploy",
    "move",
    "attack",
    "melee",
    "first_aid",
    "hold",
    "reroll",
    "advantage_use",
    "event_use",
    "quick_start_move",
}

errors = []


def load(name: str):
    path = fixtures / name
    if not path.exists():
        errors.append(f"Missing fixture: {name}")
        return None
    with path.open("r", encoding="utf-8") as fh:
        return json.load(fh)


def require(cond: bool, msg: str):
    if not cond:
        errors.append(msg)


def check_commands(cmds, label):
    if not isinstance(cmds, list) or not cmds:
        errors.append(f"{label} must be a non-empty array")
        return
    seqs = []
    for idx, cmd in enumerate(cmds):
        prefix = f"{label}[{idx}]"
        require(isinstance(cmd.get("id"), str), f"{prefix} missing id")
        require(isinstance(cmd.get("sequence"), int), f"{prefix} sequence must be int")
        seqs.append(cmd.get("sequence"))
        require(cmd.get("type") in allowed_command_types, f"{prefix} invalid type {cmd.get('type')}")
        require(isinstance(cmd.get("payload"), dict), f"{prefix} payload must be object")
        require(isinstance(cmd.get("rng_offset_before"), (int, float)), f"{prefix} rng_offset_before must be number")
        require(isinstance(cmd.get("version"), str), f"{prefix} version must be string")
    if seqs:
        require(sorted(seqs) == seqs, f"{label} sequences must be sorted")


factions = load("factions.json")
if factions is not None:
    require(isinstance(factions, list) and factions, "Factions must be a non-empty array")
    for idx, fac in enumerate(factions):
        prefix = f"Factions[{idx}]"
        require(isinstance(fac.get("id"), str), f"{prefix} missing id")
        require(isinstance(fac.get("name"), str), f"{prefix} missing name")
        require(isinstance(fac.get("roster_limit"), int), f"{prefix} roster_limit must be int")
        base = fac.get("base_stats", {})
        require(isinstance(base, dict), f"{prefix} base_stats must be object")
        move = base.get("move")
        require(isinstance(move, (int, str)), f"{prefix} base_stats.move must be int or string")
        for stat in ("range", "aq", "defense"):
            require(isinstance(base.get(stat), int), f"{prefix} base_stats.{stat} must be int")
        require(fac.get("movement_mode") in {"fixed", "roll_per_move"}, f"{prefix} movement_mode invalid")
        require(isinstance(fac.get("traits"), list), f"{prefix} traits must be array")
        require(isinstance(fac.get("version"), str), f"{prefix} version must be string")

missions = load("missions.json")
if missions is not None:
    allowed_missions = {
        "crossfire_clash",
        "control_center",
        "break_through",
        "dead_center",
        "dead_zone",
        "occupy",
    }
    require(isinstance(missions, list) and missions, "Missions must be a non-empty array")
    for idx, mis in enumerate(missions):
        prefix = f"Missions[{idx}]"
        require(isinstance(mis.get("id"), str), f"{prefix} missing id")
        require(isinstance(mis.get("name"), str), f"{prefix} missing name")
        require(mis.get("mission_type") in allowed_missions, f"{prefix} invalid mission_type {mis.get('mission_type')}")
        require(isinstance(mis.get("control_zones"), list), f"{prefix} control_zones must be array")
        require(isinstance(mis.get("scoring_rules"), dict), f"{prefix} scoring_rules must be object")
        require(mis.get("round_limit") == 6, f"{prefix} round_limit must be 6")
        require(mis.get("max_extra_rounds") == 1, f"{prefix} max_extra_rounds must be 1")
        require(mis.get("unique_per_campaign") is True, f"{prefix} unique_per_campaign must be true")
        require(isinstance(mis.get("version"), str), f"{prefix} version must be string")

terrain_templates = load("terrain_templates.json")
if terrain_templates is not None:
    require(isinstance(terrain_templates, list) and terrain_templates, "Terrain templates must be a non-empty array")
    for idx, ter in enumerate(terrain_templates):
        prefix = f"Terrain[{idx}]"
        require(isinstance(ter.get("id"), str), f"{prefix} missing id")
        require(isinstance(ter.get("name"), str), f"{prefix} missing name")
        size = ter.get("size_range", {})
        require(isinstance(size.get("min"), int), f"{prefix} size_range.min must be int")
        require(isinstance(size.get("max"), int), f"{prefix} size_range.max must be int")
        require(ter.get("blocks_los") is True, f"{prefix} blocks_los must be true")
        require(ter.get("provides_cover") is True, f"{prefix} provides_cover must be true")
        require(ter.get("impassable") is True, f"{prefix} impassable must be true")
        require(isinstance(ter.get("placement_weight"), int), f"{prefix} placement_weight must be int")
        require(isinstance(ter.get("flags"), dict), f"{prefix} flags must be object")
        require(isinstance(ter.get("version"), str), f"{prefix} version must be string")

advantages = load("advantages.json")
if advantages is not None:
    require(isinstance(advantages, list) and advantages, "Advantages must be a non-empty array")
    for idx, adv in enumerate(advantages):
        prefix = f"Advantages[{idx}]"
        require(isinstance(adv.get("id"), str), f"{prefix} missing id")
        require(isinstance(adv.get("name"), str), f"{prefix} missing name")
        require(isinstance(adv.get("effect"), str), f"{prefix} missing effect")
        require(adv.get("usage_timing") in {"pre_round", "per_round", "once_per_battle"}, f"{prefix} usage_timing invalid")
        require(isinstance(adv.get("limits"), dict), f"{prefix} limits must be object")
        require(isinstance(adv.get("version"), str), f"{prefix} version must be string")

commander_traits = load("commander_traits.json")
if commander_traits is not None:
    require(isinstance(commander_traits, list) and commander_traits, "Commander traits must be a non-empty array")
    for idx, trait in enumerate(commander_traits):
        prefix = f"CommanderTraits[{idx}]"
        require(isinstance(trait.get("id"), str), f"{prefix} missing id")
        require(isinstance(trait.get("name"), str), f"{prefix} missing name")
        require(isinstance(trait.get("effect"), str), f"{prefix} missing effect")
        require(isinstance(trait.get("version"), str), f"{prefix} version must be string")

battle_events = load("battle_events.json")
if battle_events is not None:
    require(isinstance(battle_events, list) and battle_events, "Battle events must be a non-empty array")
    for idx, event in enumerate(battle_events):
        prefix = f"BattleEvents[{idx}]"
        require(isinstance(event.get("id"), str), f"{prefix} missing id")
        require(isinstance(event.get("name"), str), f"{prefix} missing name")
        require(isinstance(event.get("effect"), str), f"{prefix} missing effect")
        require(event.get("trigger") == "pre_game", f"{prefix} trigger must be pre_game")
        require(isinstance(event.get("version"), str), f"{prefix} version must be string")

optional_rules = load("optional_rules_config.json")
if optional_rules is not None:
    require(isinstance(optional_rules, dict), "Optional rules config must be object")
    require(isinstance(optional_rules.get("commander"), bool), "Optional rules commander must be boolean")
    require(isinstance(optional_rules.get("events"), bool), "Optional rules events must be boolean")
    require(isinstance(optional_rules.get("campaign"), bool), "Optional rules campaign must be boolean")
    require(isinstance(optional_rules.get("version"), str), "Optional rules version must be string")

rng_seed = load("rng_seed.json")
if rng_seed is not None:
    require(isinstance(rng_seed, dict), "RNG seed must be object")
    require(isinstance(rng_seed.get("seed"), str), "RNG seed.seed must be string")
    require(isinstance(rng_seed.get("offset"), (int, float)), "RNG seed.offset must be number")
    require(isinstance(rng_seed.get("version"), str), "RNG seed.version must be string")

commands = load("commands.json")
if commands is not None:
    check_commands(commands, "Commands")

command_log = load("command_log.json")
if command_log is not None:
    require(isinstance(command_log, dict), "Command log must be object")
    require(isinstance(command_log.get("id"), str), "Command log id must be string")
    entries = command_log.get("entries")
    check_commands(entries if isinstance(entries, list) else [], "Command log entries")
    require(isinstance(command_log.get("checksum"), str), "Command log checksum must be string")
    require(isinstance(command_log.get("version"), str), "Command log version must be string")

match_state = load("match_state.json")
if match_state is not None:
    require(isinstance(match_state, dict), "Match state must be object")
    for field in (
        "id",
        "board_layout_id",
        "mission_id",
        "command_log_id",
        "state_hash",
        "status",
        "version",
    ):
        require(isinstance(match_state.get(field), str), f"Match state {field} must be string")
    require(isinstance(match_state.get("terrain"), list), "Match state terrain must be array")
    require(isinstance(match_state.get("optional_rules"), dict), "Match state optional_rules must be object")
    opt_rules = match_state.get("optional_rules", {})
    require(isinstance(opt_rules.get("commander"), bool), "Match state optional_rules.commander must be boolean")
    require(isinstance(opt_rules.get("events"), bool), "Match state optional_rules.events must be boolean")
    require(isinstance(opt_rules.get("campaign"), bool), "Match state optional_rules.campaign must be boolean")
    require(isinstance(match_state.get("player_states"), list), "Match state player_states must be array")
    require(isinstance(match_state.get("unit_states"), list), "Match state unit_states must be array")
    round_state = match_state.get("round_state", {})
    require(isinstance(round_state, dict), "Match state round_state must be object")
    if isinstance(round_state, dict):
        require(round_state.get("extra_rounds_remaining", 0) <= 1, "Match state round_state.extra_rounds_remaining must be <= 1")
    rng = match_state.get("rng", {})
    require(isinstance(rng, dict), "Match state rng must be object")
    require(isinstance(rng.get("seed"), str), "Match state rng.seed must be string")
    require(isinstance(rng.get("offset"), (int, float)), "Match state rng.offset must be number")

campaign_state = load("campaign_state.json")
if campaign_state is not None:
    require(isinstance(campaign_state, dict), "Campaign state must be object")
    require(isinstance(campaign_state.get("id"), str), "Campaign state id must be string")
    length = campaign_state.get("length")
    require(isinstance(length, int) and 3 <= length <= 5, "Campaign length must be int between 3 and 5")
    require(isinstance(campaign_state.get("current_battle"), int), "Campaign current_battle must be int")
    require(isinstance(campaign_state.get("missions_used"), list), "Campaign missions_used must be array")
    require(isinstance(campaign_state.get("cumulative_scores"), dict), "Campaign cumulative_scores must be object")
    require(isinstance(campaign_state.get("advantages_history"), list), "Campaign advantages_history must be array")
    rng = campaign_state.get("rng", {})
    require(isinstance(rng, dict), "Campaign rng must be object")
    require(isinstance(rng.get("seed"), str), "Campaign rng.seed must be string")
    require(isinstance(rng.get("offset"), (int, float)), "Campaign rng.offset must be number")
    require(isinstance(campaign_state.get("version"), str), "Campaign version must be string")

if errors:
    for err in errors:
        print(f"[schema-parity][fail] {err}")
    print("[schema-parity] FAIL")
    sys.exit(1)

print("[schema-parity] All fixture shape checks passed.")
sys.exit(0)
PY
