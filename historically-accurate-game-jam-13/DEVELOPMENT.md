# Working on the playground

Open this directory as the Godot project. Start from `Scenes/Game/Game.tscn`.
Scene behavior belongs in the scene family's `Scripts/` directory. Shared definitions
and services live in `Code/`; editable game content lives in `GameData/`.

## Ownership

| Responsibility | Owner |
| --- | --- |
| Menus, pause, room changes and input routing | `Scenes/Game/Scripts/game_shell.gd` |
| Transition timing and animation | `Scenes/Game/Scripts/screen_transition.gd` |
| Room scene and chapter labels | `Code/Registries/scene_catalog.gd` |
| Room wiring | `Scenes/Levels/Scripts/laika_room.gd` |
| Objectives, conditions and story events | `Scenes/Levels/Scripts/Progress/` |
| Ray targeting, carrying and scent | `Scenes/Player/Scripts/Components/` |
| Reusable interaction behavior | `Scenes/Shared/Scripts/Interactions/` |
| Dialogue content | `GameData/Dialogue/Training/`, `GameData/Dialogue/Station/` |
| Dialogue state / presentation | `Code/Services/dialogue_session.gd` / `Scenes/GUI/Components/Scripts/dialogue_panel.gd` |
| Settings definitions / storage / effects | `GameData/Settings/settings_catalog.gd` / `Code/Services/game_settings.gd` / `Code/Services/settings_effects.gd` |

The room connects its components once. Interactions ask their action resource what
to do; they do not dispatch on object names. Level progress handles story events.
Resources describe behavior; mutable progress and carried-item state belong to nodes.

## Add an interactive object

1. Group the whole asset under one named `Node3D`, with visuals and collision as children.
2. Attach `Scenes/Shared/Scripts/interaction_point.gd` to its interactive `StaticBody3D`.
3. Set `display_name`, a descriptive `interaction_id`, and an `action` resource in Inspector.
   IDs help identify objects; they do not require a branch in `LaikaRoom`.
4. Choose an existing action:
   - `PickupAction`: set `item_id`, `item_name`, `item_mesh`, `item_shape` and optionally `scent_marker` on the point.
   - `SocketAction`: add an `ItemSocket` node and assign it to the point's `socket`.
     Set its `accepted_item` and `capacity`; optional `indicators` are revealed in order.
   - `TalkAction`: set `dialogue_id`; optionally select dialogues by progress flags or provide a completed message.
   - `EventAction`: set `event_id` and handle it in the level's progress component.
   - `ExitAction`: set the destination room ID and optional blocked message.
5. Use the action's `required_flag` for story gating. Set that flag in level progress.

Room startup finds the authored interaction points automatically. Raycasts use the
point's collision, so keep its collision layer compatible with the interactor mask.
New runtime objects can use the same actions; runtime scent markers need registration
in the room's `interactables` list. Items retain their world size when picked up.

For new behavior, extend `InteractionAction` in the interactions directory and implement
`execute(room, target)`, with `prompt` or `is_available` when needed. Keep state in a
component or the level's progress, rather than a shared action resource.

## Add a conversation

Use `01_`, `02_`, etc. for the mandatory sequence within a level. Put conversations
that can be revisited in `Optional/`, without a story number. See `GameData/Dialogue/README.md`.
Each file is a data script:

```gdscript
extends RefCounted

const LINES := [
    {"speaker": "Scientist", "text": "Ready?", "bark": true},
    {"speaker": "Laika", "text": "I know this game."},
]
```

Register its ID and preload in `Code/Registries/dialogue_catalog.gd`, then select that ID
on a `TalkAction` or emit `room.dialogue_requested` from progress. Handle completion
in the progress component's `complete_dialogue(id)` when it advances the story.
A line with `bark: true` needs the bark action; ordinary lines need interact.
Movement and camera look remain available during conversation; world interactions
and scent are suspended. The session owns progression, the panel only presents it.

## Add a setting

Add one entry to `SettingsCatalog.DEFINITIONS`. Use named fields:

```gdscript
&"invert_y": {
    "section": &"input",
    "label": "Invert mouse Y",
    "default": false,
    "effect": [&"player", &"invert_y"],
},
```

UI, validation, storage and effects use that entry. Do not add another property or
setter to `GameSettings` or `SettingsPanel`. Read with `get_value(id)`, write with
`set_value(id, value)`, and access a UI editor with `panel.row(id).editor`.

Sections are `display`, `audio`, `input`. Boolean defaults make toggles, float defaults
make sliders, integer defaults make choices. Sliders optionally declare `minimum`,
`maximum`, `step`, `format`; choices declare `options`. Values stay untranslated.
`effect` contains a target and property: `player` is the FPS camera rig, `projection`
is Panini, `dog_vision` is the filter. Add a target to the shell mapping only for a new
system. `bus` maps an audio slider to an audio bus.

Only window mode and resolution have `confirmation: true`; these share Apply / Keep /
Revert. New display transactions need explicit `GameSettings` support. Ordinary settings
apply immediately and save on Back. Dog vision and Panini default to enabled; saved
choices take precedence. Register definitions before initialization and panel setup.

New controls belong in `PlayerBindings.ACTIONS` with their label/default event; binding
rows are generated automatically and enforce one binding per action.

## Add a level

Use an existing room as the composition reference: assign its player, rig, cameras,
carry anchor, scent root and progress component in Inspector, and retain `Systems/Carry`,
`Systems/Interactor`, `Systems/Scent`. Extend `RoomProgress` for this level's objectives,
flags and events. Register its PackedScene and chapter text once in `SceneCatalog.ROOMS`.
Connect exits using the new room ID. Emit `room.completed` for the completion notice.

Keep artist-authored dimensions, camera transforms, meshes and rig setup in scenes.
The menu gaze moves only `LookAtTarget`; snout lag is a separate component with a bounded, smoothed angular-velocity target.
The completion notice never changes mouse capture; use the ordinary pause menu for a cursor. The original
FPS movement and camera scripts retain their existing names and behavior. Scientist
head/body blocks are placeholders with their own nearby-player gaze component.

## Verify changes

From this directory, replace `godot` with the installed Godot 4 executable:

```sh
godot --headless --path . --script res://tests/whole_flow/architecture_flow.gd
godot --headless --path . --script res://tests/whole_flow/opening_flow.gd
godot --headless --path . --script res://tests/whole_flow/settings_flow.gd
godot --headless --path . --script res://tests/whole_flow/menu_gaze_flow.gd
```

Use isolated `XDG_CONFIG_HOME`, `XDG_DATA_HOME` and `XDG_CACHE_HOME` directories for
regression runs; settings tests intentionally save preferences. Repeat without
`--headless` to validate real window modes, projection and rendered framing. Walk
training through both batteries, test, capsule and station conversation. Check settings
at 960×540 and 1280×720, and menu gaze at another aspect ratio after layout changes.

## Translation

Use readable English source text. Use `tr("Full sentence with %s") % value` for dynamic
sentences: translate before formatting and avoid building sentences from fragments.
Keep IDs, resource paths, settings values and developer diagnostics untranslated.
Controls in scenes use Godot automatic translation. Data scripts store English keys;
the presenting node calls `tr()` for dialogue lines, speakers, labels and choices.

After changing text, run from the project directory:

```sh
python3 Tools/Localization/export_messages.py
python3 Tools/Localization/export_messages.py --check
```

This exports literal `tr` calls plus dialogue/catalog data, bindings and the known
player-facing scene/export properties into `GameData/Localization/messages.pot`.
Custom data fields must also be added to that extractor. The built-in POT scan alone
does not cover our constant data tables. Copy the template to a locale `.po`, set its
Language header, translate msgstr values and add it under Project Settings →
Localization → Translations. No language selector or completed translations ship yet.
`localization_flow.gd` verifies the pipeline with a temporary Ukrainian translation.

## Formatting (separate change)

`gdtoolkit==4.3.4` is pinned in the repository's `requirements-dev.txt`. `gdformatrc`
sets tabs, 100-column wrapping and safety checks. `Tools/format_code.py --check` checks
our scripts and `--write` formats them. Both require explicit invocation; no hook or
CI formatting gate runs them. Artist FPS scripts and the existing projection directory
are excluded. The functional changes were deliberately not run through the formatter;
apply formatting in its own later commit.
