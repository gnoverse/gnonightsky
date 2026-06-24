#!/usr/bin/env python3
"""Dummy telescope driver: `capture <ra> <dec> <exposure>` or `stop`."""

import os
import sys
import time
import datetime
import random

OUTPUT_FILE = os.environ.get("TELESCOPE_OUTPUT", "tmp.jpg")
MAX_SLEEP = 3.0


def log(msg):
    print(f"[telescope_control] {msg}", flush=True)


def write_image(ra, dec, exposure):
    from PIL import Image, ImageDraw

    img = Image.new("RGB", (640, 480), (5, 5, 20))
    draw = ImageDraw.Draw(img)

    rng = random.Random(f"{ra}:{dec}:{exposure}")
    for _ in range(400):
        b = rng.randint(120, 255)
        draw.point((rng.randint(0, 639), rng.randint(0, 479)), fill=(b, b, b))

    lines = [
        "GnoNightSky DUMMY capture",
        f"RA  = {ra} h",
        f"Dec = {dec} deg",
        f"Exposure = {exposure} s",
        datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
    ]
    for i, line in enumerate(lines):
        draw.text((10, 10 + i * 16), line, fill=(180, 220, 255))

    img.save(OUTPUT_FILE, "JPEG", quality=85)
    log(f"wrote {OUTPUT_FILE}")


def do_capture(args):
    if len(args) < 3:
        log("usage: capture <ra> <dec> <exposure>")
        return 1
    ra, dec, exposure = args[0], args[1], int(float(args[2]))

    log(f"slewing to RA={ra}h Dec={dec}deg ...")
    time.sleep(min(max(exposure, 0), MAX_SLEEP))
    write_image(ra, dec, exposure)
    log("capture complete")
    return 0


def do_stop(_args):
    log("stopped")
    return 0


def main(argv):
    action = argv[1] if len(argv) > 1 else ""
    if action == "capture":
        return do_capture(argv[2:])
    if action == "stop":
        return do_stop(argv[2:])
    log("usage: telescope_control.py <capture|stop> [args...]")
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv))
