import argparse
import ast
import json
import re
from collections import defaultdict
from pathlib import Path

PROJECT = Path(__file__).resolve().parents[2]
OUTPUT = PROJECT / "GameData/Localization/messages.pot"
QUOTED = r'"(?:[^"\\]|\\.)*"|\'(?:[^\'\\]|\\.)*\''
TRIPLE = r'"""(?:\\.|[^\\])*?"""|\'\'\'(?:\\.|[^\\])*?\'\'\''
STRING = f"(?:{TRIPLE}|{QUOTED})"
DATA_FIELDS = "speaker|text|title|heading|label"
SCENE_FIELDS = (
    "text|tooltip_text|caption|display_name|item_name|blocked_message|"
    "completed_message|completed_prompt|empty_message|mismatch_message"
)


def extract(path):
    source = path.read_text(encoding="utf-8")
    if path.suffix == ".gd":
        source = re.sub(STRING + r"|\#[^\n]*", lambda match: " " * len(match[0]) if match[0].startswith("#") else match[0], source)
    if path.suffix == ".tscn":
        patterns = [rf"(?m)^(?:{SCENE_FIELDS})\s*=\s*({STRING})"]
    else:
        patterns = [
            rf"\b(?:tr|translate)\(\s*(?:\(\s*)?&?({STRING})",
            rf"(?:thought_requested\.emit|show_thought|objective_changed\.emit)\(\s*(?:\(\s*)?({STRING})",
            rf"objective_changed\.emit\(\s*{STRING}\s*,\s*({STRING})",
            rf'["\'](?:{DATA_FIELDS})["\']\s*:\s*(?:\(\s*)?({STRING})',
            rf"(?m)^@export[^\n]*\b(?:{SCENE_FIELDS})[^=\n]*=\s*(?:\(\s*)?({STRING})",
        ]
        for match in re.finditer(r'''["']options["']\s*:\s*\[([^\]]*)\]''', source):
            for text in re.finditer(STRING, match[1]):
                yield match.start(1) + text.start(), _string(text[0])
        if path.name == "player_bindings.gd":
            actions = re.search(r"const ACTIONS[^=]*=\s*\{([^}]+)\}", source)
            for text in re.finditer(rf":\s*({STRING})", actions[1] if actions else ""):
                yield actions.start(1) + text.start(1), _string(text[1])
        if path.name == "input_hints.gd":
            for text in re.finditer(rf":\s*({STRING})|\.get\(event.button_index,\s*({STRING})", source):
                token = text[1] or text[2]
                yield text.start(), _string(token)
    for pattern in patterns:
        for match in re.finditer(pattern, source):
            yield match.start(1), _string(match[1])



def _string(token):
    try:
        return ast.literal_eval(token)
    except SyntaxError:
        return json.loads(token, strict=False)


def render():
    messages = defaultdict(set)
    for folder in ("Code", "GameData", "Scenes"):
        for path in sorted((PROJECT / folder).rglob("*")):
            if path.suffix not in (".gd", ".tscn"):
                continue
            source = path.read_text(encoding="utf-8")
            for offset, message in extract(path):
                if message and any(character.isalpha() for character in message):
                    line = source.count("\n", 0, offset) + 1
                    messages[message].add(f"{path.relative_to(PROJECT).as_posix()}:{line}")
    lines = [
        'msgid ""',
        'msgstr ""',
        '"Project-Id-Version: Laika\\n"',
        '"MIME-Version: 1.0\\n"',
        '"Content-Type: text/plain; charset=UTF-8\\n"',
        '"Content-Transfer-Encoding: 8bit\\n"',
        "",
    ]
    for message, locations in sorted(messages.items()):
        lines.append("#: " + " ".join(sorted(locations)))
        if re.search(r"%(?:\d+\$)?[sdif]", message):
            lines.append("#, c-format")
        lines.extend(["msgid " + json.dumps(message, ensure_ascii=False), 'msgstr ""', ""])
    return "\n".join(lines), len(messages)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true")
    arguments = parser.parse_args()
    content, count = render()
    if arguments.check:
        if not OUTPUT.exists() or OUTPUT.read_text(encoding="utf-8") != content:
            parser.exit(1, "Translation template is stale; run Tools/Localization/export_messages.py.\n")
    else:
        OUTPUT.parent.mkdir(parents=True, exist_ok=True)
        OUTPUT.write_text(content, encoding="utf-8")
    print(f"Translation template: {count} messages")


if __name__ == "__main__":
    main()
