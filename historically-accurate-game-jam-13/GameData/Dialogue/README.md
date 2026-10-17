# Dialogue order

| Level | File | ID | Trigger |
| --- | --- | --- | --- |
| Training | `Training/01_greeting.gd` | `greeting` | Enter training |
| Training | `Training/02_trained.gd` | `trained` | Test with both batteries installed |
| Training | `Training/Optional/reminder.gd` | `reminder` | Talk to the scientist during collection |
| Training | `Training/Optional/scientist.gd` | `scientist` | Talk to the scientist outside collection |
| Station | `Station/01_arrival.gd` | `arrival` | Enter the station |
| Station | `Station/02_robot.gd` | `robot` | Talk to the robot |

Numbers help browse the mandatory sequence within a level. They do not schedule
conversations. Progress components and Inspector action resources choose stable IDs;
optional conversations depend on interaction and state, rather than a random order.

A content file contains `const LINES`, an array of speaker/text dictionaries with an
optional `bark` flag. Register the ID once in `Code/Registries/dialogue_catalog.gd`.
The catalog gives each session a deep copy, and the panel translates the source text
when displaying it. Regenerate `GameData/Localization/messages.pot` after editing text.
