#!/usr/bin/env python3
"""Generate ui/Glyphs.js from the bundled Material Symbols Rounded font.

Usage: python3 tools/gen-glyphs.py
"""
import os
import sys

from fontTools.ttLib import TTFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FONT = os.path.join(ROOT, "assets", "fonts", "MaterialSymbolsRounded.ttf")
OUT = os.path.join(ROOT, "ui", "Glyphs.js")

# Иконки, которые использует Nimbus (и запас на будущее).
WANTED = """
notifications power_settings_new wifi bluetooth volume_up volume_down volume_off volume_mute
brightness_6 light_mode dark_mode image wallpaper description content_copy check refresh delete push_pin
visibility visibility_off pause play_arrow skip_previous skip_next music_note movie lock logout arrow_back
close search settings palette screenshot photo_camera videocam more_vert drag_indicator add remove
chevron_right chevron_left expand_more expand_less fullscreen fullscreen_exit restart_alt bedtime monitor
graphic_eq smart_display slideshow folder edit tune mic system_update_alt speed
timer schedule alarm calendar_today event today language translate info error warning star favorite
download upload open_in_new link south east north west arrow_forward arrow_upward arrow_downward
brightness_high brightness_low wb_sunny nightlight lightbulb power battery_full
do_not_disturb_on photo_library clear_all sort animation public play_circle pause_circle smartphone
brightness_auto wallpaper select_all deselect delete_sweep
""".split()


def main() -> int:
    tt = TTFont(FONT)
    cmap = tt.getBestCmap()
    inv = {}
    for cp, name in cmap.items():
        inv.setdefault(name, cp)

    missing = [n for n in WANTED if n not in inv]
    if missing:
        print("WARN: not in font:", ", ".join(missing), file=sys.stderr)

    lines = [
        "// Материальные символы (Material Symbols Rounded).",
        "// Сгенерировано tools/gen-glyphs.py из assets/fonts/MaterialSymbolsRounded.ttf.",
        "// Не редактировать вручную.",
        ".pragma library",
        "",
        "var cp = {",
    ]
    for n in WANTED:
        if n in inv:
            lines.append('    "%s": 0x%04x,' % (n, inv[n]))
    lines.append("};")
    lines.append("")

    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with open(OUT, "w") as f:
        f.write("\n".join(lines))
    print("wrote %s (%d icons)" % (OUT, len(WANTED) - len(missing)))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
