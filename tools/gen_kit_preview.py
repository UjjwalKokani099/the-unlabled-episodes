"""Builds tests/scenes/kit_preview.tscn: one Shanti Vihar style wing at night, with a
street lamp, ground, and the player. Used to review and benchmark the building kit.
Run: python tools/gen_kit_preview.py
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from levelkit import (ROOT, Level, benchmark_points, night_environment, player_rig,  # noqa: E402
                      residential_wing, sodium_lamp)


def main() -> None:
    lv = Level("KitPreview")
    night_environment(lv)
    # ground: paver blocks around, asphalt drive in front
    lv.box((6, -0.1, 5), (40, 0.2, 34), "ground_pavers")
    lv.box((6, -0.095, 19), (40, 0.2, 6), "ground_asphalt", collide=False)
    residential_wing(lv, "WingB", 0, 0, letter="B", exterior="wall_exterior_cream",
                     lit_floors=(2,), tv_floors=(3,), interior_floor=4, flicker_floors=(3,),
                     unlocked_doors=("4B",))
    sodium_lamp(lv, 14.5, 15.0, facing_x=-1.0, shadow=True)
    sodium_lamp(lv, -4.0, 16.0, facing_x=1.0)
    player_rig(lv, 6.0, 20.0, 180.0)
    benchmark_points(lv, [(6, 0, 20), (1.5, 6.0, 9.2), (7.5, 15.0, 5.0), (8.0, 12.0, 3.0)])
    lv.write(os.path.join(ROOT, "tests", "scenes", "kit_preview.tscn"))


if __name__ == "__main__":
    main()
