#!/usr/bin/env python3
"""Reject emoji and decorative pictographs in Git commit messages."""

from __future__ import annotations

import argparse
from pathlib import Path
import sys


DISALLOWED_RANGES = (
    (0x1F000, 0x1FAFF),  # Mahjong, symbols, pictographs, flags, and emoji
    (0x2600, 0x27BF),  # Miscellaneous symbols and dingbats
    (0x2300, 0x23FF),  # Technical symbols commonly rendered as emoji
    (0x2B00, 0x2BFF),  # Miscellaneous symbols and arrows
    (0xFE00, 0xFE0F),  # Variation selectors, including emoji presentation
    (0x1F1E6, 0x1F1FF),  # Regional indicator flags
)
DISALLOWED_CODEPOINTS = {0x200D, 0x20E3, 0x00A9, 0x00AE, 0x2122}


def disallowed_characters(message: str) -> list[str]:
    return [
        character
        for character in message
        if ord(character) in DISALLOWED_CODEPOINTS
        or any(start <= ord(character) <= end for start, end in DISALLOWED_RANGES)
    ]


def main() -> int:
    parser = argparse.ArgumentParser()
    source = parser.add_mutually_exclusive_group(required=True)
    source.add_argument("--file", type=Path, help="path to a commit message file")
    source.add_argument("--message", help="commit message text")
    args = parser.parse_args()

    message = args.file.read_text(encoding="utf-8") if args.file else args.message
    found = disallowed_characters(message)
    if not found:
        return 0

    rendered = " ".join(f"U+{ord(character):04X}" for character in dict.fromkeys(found))
    print("Commit rejected: RHOIDS commit messages must not contain emoji or decorative symbols.", file=sys.stderr)
    print(f"Remove these characters and try again: {rendered}", file=sys.stderr)
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
