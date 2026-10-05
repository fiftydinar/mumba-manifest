#!/usr/bin/env python3
"""Generate Serbian Latin Android resources from Messaging's Serbian Cyrillic files."""

import re
import sys
from pathlib import Path


CYRILLIC_TO_LATIN = str.maketrans({
    "а": "a", "б": "b", "в": "v", "г": "g", "д": "d", "ђ": "đ", "е": "e",
    "ж": "ž", "з": "z", "и": "i", "ј": "j", "к": "k", "л": "l", "љ": "lj",
    "м": "m", "н": "n", "њ": "nj", "о": "o", "п": "p", "р": "r", "с": "s",
    "т": "t", "ћ": "ć", "у": "u", "ф": "f", "х": "h", "ц": "c", "ч": "č",
    "џ": "dž", "ш": "š",
    "А": "A", "Б": "B", "В": "V", "Г": "G", "Д": "D", "Ђ": "Đ", "Е": "E",
    "Ж": "Ž", "З": "Z", "И": "I", "Ј": "J", "К": "K", "Л": "L", "Љ": "Lj",
    "М": "M", "Н": "N", "Њ": "Nj", "О": "O", "П": "P", "Р": "R", "С": "S",
    "Т": "T", "Ћ": "Ć", "У": "U", "Ф": "F", "Х": "H", "Ц": "C", "Ч": "Č",
    "Џ": "Dž", "Ш": "Š",
})
TEXT_BETWEEN_TAGS = re.compile(r">([^<>]+)<")


def transliterate_resource(xml_text: str) -> str:
    translated = TEXT_BETWEEN_TAGS.sub(
        lambda match: ">" + match.group(1).translate(CYRILLIC_TO_LATIN) + "<", xml_text
    )
    return re.sub(r"(?m)^(\s*<!--)\s+$", r"\1", translated)


def main() -> None:
    if len(sys.argv) != 2:
        raise SystemExit(f"Usage: {sys.argv[0]} MESSAGING_RES_DIR")

    resource_dir = Path(sys.argv[1])
    source_dir = resource_dir / "values-sr"
    output_dir = resource_dir / "values-b+sr+Latn"
    if not source_dir.is_dir():
        raise SystemExit(f"Serbian resource directory not found: {source_dir}")

    output_dir.mkdir(parents=True, exist_ok=True)
    generated = 0
    for source_file in sorted(source_dir.glob("*.xml")):
        output_file = output_dir / source_file.name
        translated = transliterate_resource(source_file.read_text(encoding="utf-8"))
        if not output_file.exists() or output_file.read_text(encoding="utf-8") != translated:
            output_file.write_text(translated, encoding="utf-8")
        generated += 1

    if generated == 0:
        raise SystemExit(f"No Serbian resource XML files found in {source_dir}")
    print(f"Generated {generated} Serbian Latin resource files in {output_dir}")


if __name__ == "__main__":
    main()
