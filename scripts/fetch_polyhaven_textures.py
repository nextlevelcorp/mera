#!/usr/bin/env python3
"""Fetches the CC0 PBR textures of game/assets/3d from Poly Haven.

A developer tool, not part of the game: it needs curl and Pillow. For each
asset it downloads the 1k JPG maps (diffuse, OpenGL normal, roughness) from
dl.polyhaven.org, shrinks them to 512 px (the phone's memory budget, see
docs/architecture.md section 6) and writes them as lossy WebP next to a
source.txt with the origin and licence. Licence rows live in
docs/reference_docs.md; add one before committing a new asset.

Usage: python3 scripts/fetch_polyhaven_textures.py            (all assets)
       python3 scripts/fetch_polyhaven_textures.py metal_plate (one asset)
"""
import os
import subprocess
import sys
import tempfile

from PIL import Image

BASE = "https://dl.polyhaven.org/file/ph-assets/Textures/jpg/1k"
OUT = os.path.join(os.path.dirname(__file__), "..", "game", "assets", "3d")
SIZE = 512
QUALITY = 82
# game name -> (what it is used for)
ASSETS = {
    "concrete_pavement": "bridge deck paving",
    "metal_plate": "bridge rail and lamp standards",
    "cobblestone_floor_04": "quay apron",
    "rough_concrete": "quay coping",
    "rusty_metal_02": "quay bollards",
    "stone_wall_04": "quay wall below the waterline",
    "coast_sand_01": "beach sand",
}
MAPS = {"diff": "diff", "nor_gl": "nor", "rough": "rough"}


def fetch(asset: str) -> None:
    folder = os.path.join(OUT, asset)
    os.makedirs(folder, exist_ok=True)
    with tempfile.TemporaryDirectory() as tmp:
        for src, dst in MAPS.items():
            url = f"{BASE}/{asset}/{asset}_{src}_1k.jpg"
            path = os.path.join(tmp, f"{src}.jpg")
            subprocess.run(["curl", "-sS", "-f", "-m", "60", "-o", path, url], check=True)
            img = Image.open(path)
            mode = "RGB" if dst != "rough" else "L"
            img = img.convert(mode).resize((SIZE, SIZE), Image.LANCZOS)
            img.save(os.path.join(folder, f"{dst}.webp"), "WEBP", quality=QUALITY, method=6)
    with open(os.path.join(folder, "source.txt"), "w") as f:
        f.write(f"{asset}: {ASSETS[asset]}\n"
                f"Source: https://polyhaven.com/a/{asset}\n"
                f"Files: {BASE}/{asset}/\n"
                "Licence: CC0 1.0 per Poly Haven's licence policy (https://polyhaven.com/license). The asset page itself\n"
                "was not readable from the build environment (HTTP 403) when this was fetched: verify it there.\n"
                f"Processing: 1k JPG diffuse, OpenGL normal and roughness maps, resized to {SIZE} px, lossy WebP quality {QUALITY}.\n")


if __name__ == "__main__":
    for name in (sys.argv[1:] or list(ASSETS)):
        fetch(name)
        print("fetched", name)
