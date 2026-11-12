#!/usr/bin/env python3
"""Packs a Godot web export into the page used for the Claude test link.

The test link can only serve a few file types and no file over 15 MB, so the
38 MB engine is gzip-compressed (the page unpacks it) and the game data is
embedded as text. For a normal website you do not need this: upload Godot's
own export (build/web) as it is.

Usage:
    godot --headless --path . --export-release Web build/web/index.html
    python3 dev/build_test_page.py build/web build/test_page
"""
import base64
import gzip
import pathlib
import shutil
import sys

SKELETON = ('<!doctype html><html><head><meta charset="utf-8">'
            '<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">'
            '<style>body{margin:0}[hidden]{display:none!important}</style></head><body>')


def main() -> None:
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    src, out = pathlib.Path(sys.argv[1]), pathlib.Path(sys.argv[2])
    out.mkdir(parents=True, exist_ok=True)

    wasm = (src / "index.wasm").read_bytes()
    packed = gzip.compress(wasm, 9, mtime=0)
    (out / "engine.wasm").write_bytes(packed)
    pck = (src / "index.pck").read_bytes()
    (out / "pck.js").write_text('window.ORBIT_PCK_B64="%s";\n' % base64.b64encode(pck).decode())
    for name in ("index.js", "index.audio.worklet.js", "index.audio.position.worklet.js"):
        shutil.copy(src / name, out / name)

    page = (pathlib.Path(__file__).parent / "test_page.html").read_text()
    page = page.replace("__ENGINE_GZ_BYTES__", str(len(packed)))
    page = page.replace("__PCK_BYTES__", str(len(pck)))
    page = page.replace("__WASM_BYTES__", str(len(wasm)))
    (out / "orbit.html").write_text(page)
    # The test link wraps orbit.html in a page skeleton; preview.html does the
    # same so the result can be opened from a local web server.
    (out / "preview.html").write_text(SKELETON + page + "</body></html>")
    print("engine %d bytes packed, game data %d bytes -> %s" % (len(packed), len(pck), out))


if __name__ == "__main__":
    main()
