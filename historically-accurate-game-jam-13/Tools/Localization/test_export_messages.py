import tempfile
import unittest
from pathlib import Path

from export_messages import extract


class MessageExtractionTests(unittest.TestCase):
    def messages(self, source, suffix=".gd"):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / ("content" + suffix)
            path.write_text(source, encoding="utf-8")
            return {text for _, text in extract(path)}

    def test_wrapped_calls_and_single_quotes(self):
        source = 'tr(\n    ("Keep settings?")\n)\ntr(\'Продовжити\')\n'
        self.assertEqual(self.messages(source), {"Keep settings?", "Продовжити"})

    def test_multiline_data_and_choices(self):
        source = "const LINES = [{'text': (\"\"\"First\nSecond\"\"\"), 'speaker': 'Robot'}]\n"
        source += "const OPTIONS = {'options': ['Windowed', 'Fullscreen']}"
        self.assertEqual(self.messages(source), {"First\nSecond", "Robot", "Windowed", "Fullscreen"})

    def test_templates_are_extracted_before_interpolation(self):
        source = 'room.objective_changed.emit("Bring a cell", "%d / %d CELLS", [count, limit])\n'
        source += 'room.thought_requested.emit("Found it!")\n'
        self.assertEqual(self.messages(source), {"Bring a cell", "%d / %d CELLS", "Found it!"})

    def test_wrapped_export_defaults(self):
        source = '@export var empty_message: String = (\n    "Empty slot"\n)'
        self.assertEqual(self.messages(source), {"Empty slot"})

    def test_comments_and_identifiers_are_not_messages(self):
        source = '# tr("Comment only")\nroom.dialogue_requested.emit(&"greeting")\ntr("Room #1")\n'
        self.assertEqual(self.messages(source), {"Room #1"})

    def test_scene_properties_include_custom_prompts(self):
        source = 'text = "Settings"\nitem_name = "battery"\nmismatch_message = "Wrong item"\nitem_id = &"cell"'
        self.assertEqual(self.messages(source, ".tscn"), {"Settings", "battery", "Wrong item"})


if __name__ == "__main__":
    unittest.main()
