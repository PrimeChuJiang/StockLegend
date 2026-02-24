# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Role & Communication

- **始终使用中文与用户对话**
- 你的角色是**游戏设计师 + Godot 程序员**，与用户共同完成整个游戏原型的设计与开发
- 在讨论游戏机制、系统设计时，主动从游戏设计角度提出建议和权衡
- 在编写代码时，遵循 Godot 最佳实践并保持架构一致性

## Project Overview

StockLegend is a turn-based card game built with **Godot 4.4** (GDScript). The project implements a pure-logic card game framework with no UI layer yet.

## Running the Project

- **Engine**: Godot 4.4 stable (Forward Plus renderer)
- **Test scene**: Run `scenes/test_battle.tscn` to execute a full turn simulation — check the Output panel for logs
- No build step required; open project in Godot editor and press F5/F6

## Architecture

Three-layer architecture with strict separation:

### Data Layer (`src/data/`)
Immutable card definitions as Godot `Resource` classes. `CardDef` and `EffectDef` are templates — never mutated at runtime. `Enums` holds all shared enumerations (CardType, Phase, StatKey, ModifierOp, TargetType, EffectTrigger, Zone).

### Runtime Layer (`src/runtime/`)
Mutable game state. `CardBase` (extends `RefCounted`) is the base class for all runtime card instances, with subclasses `NormalCard`, `InstantCard`, and `FieldCard` that override `can_play_at_phase()` and `execute()`. Use the factory `CardBase.create_from_def(card_def)` to instantiate — never construct subclasses directly. `Modifier` applies temporary/permanent stat changes to cards; `get_stat()` computes final values by layering modifiers (ADD → MULTIPLY → SET priority).

### Systems Layer (`src/systems/`)
Game logic nodes added to the scene tree. `TurnSystem` drives a configurable phase sequence (TURN_START → DRAW → MAIN → TURN_END → CLEANUP) with `insert_phase_before/after()` for extensibility. `ZoneManager` tracks cards across zones (DECK, HAND, FIELD, DISCARD, EXHAUST). `EffectResolver` maps `effect_id` StringNames to Callable handlers via a registry — register new effects with `register_effect()`. `TargetSelector` provides a `select_callback` hook for UI-driven target selection (defaults to auto-select).

### Signal Bus (`src/autoload/game_bus.gd`)
`GameBus` is an AutoLoad singleton. All inter-system communication goes through its signals — systems never reference each other directly. Key signals: `turn_started/ended`, `phase_started/ended`, `card_played`, `card_zone_changed`, `damage_dealt`, `modifier_added/removed`, `main_phase_entered/finished`.

## Key Patterns

- **Context Dictionary**: `TurnSystem._build_context()` creates a `{zone_manager, effect_resolver, turn_system}` dict passed to `card.execute(ctx)` — this is how cards access systems without coupling
- **Card play flow**: `TurnSystem.play_card()` checks `can_play_at_phase()` → checks energy cost → calls `card.execute(ctx)` (polymorphic dispatch) → emits `card_played`
- **Field card turn-end**: `TurnSystem._resolve_field_effects()` iterates field zone cards and resolves `ON_TURN_END` effects; always iterate a `.duplicate()` of zone arrays to avoid mutation during iteration
- **Modifier lifecycle**: Applied via `add_modifier()` → ticked each CLEANUP phase via `tick_modifiers()` → auto-removed when `duration` reaches 0

## Card Type Behavior

| Type | Play Timing | execute() Behavior |
|------|------------|-------------------|
| NormalCard | MAIN phase only | Resolve ON_PLAY → move to DISCARD |
| InstantCard | Any phase | Resolve ON_PLAY → move to DISCARD |
| FieldCard | MAIN phase only | Move to FIELD → resolve ON_FIELD_ENTER (ON_TURN_END resolved by TurnSystem) |

## GDScript Conventions

- Use tabs for indentation (Godot standard)
- All custom classes use `class_name` for global registration
- Data classes extend `Resource`; runtime objects extend `RefCounted`; system nodes extend `Node`
- Use `&"string_name"` syntax for StringName literals (effect IDs, card IDs)
- Prefix private members/methods with `_`
