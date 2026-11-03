"""Benchmark the actual renderer on macOS without launching or changing the app.

Usage: python3 Checks/run-dither-rendering-checks.py /tmp/dither-current
Use --compare /tmp/dither-baseline to require identical rendered pixels.
The output directory contains timings and raw BGRA frames, not app resources.
"""
import argparse
import json
from pathlib import Path
import subprocess
import tempfile

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("output", type=Path)
parser.add_argument("--compare", type=Path)
parser.add_argument("--swift-source", type=Path)
parser.add_argument("--metal-source", type=Path)
args = parser.parse_args()
repo = Path(__file__).resolve().parent.parent
swift = args.swift_source or repo / "Ergo/Views/Dither/DitherView.swift"
metal = args.metal_source or repo / "Ergo/Views/Dither/OptimizedDither.metal"
args.output.mkdir(parents=True, exist_ok=True)

with tempfile.TemporaryDirectory(prefix="ergo-dither-checks-") as temporary:
    build = Path(temporary)
    source = swift.read_text().split("/// An interactive Metal background.")[0]
    # The standalone executable loads the same shader library from this build directory.
    source = source.replace(
        "device.makeDefaultLibrary(bundle: Bundle(for: DitherMetalBundleMarker.self))",
        "device.makeLibrary(URL: URL(fileURLWithPath: "
        + json.dumps(str(build / "default.metallib")) + "))",
    )
    source += (repo / "Checks/DitherRenderingChecks.swift").read_text()
    (build / "Renderer.swift").write_text(source)
    commands = [
        ["xcrun", "-sdk", "macosx", "metal", "-c", str(metal), "-o", str(build / "shader.air")],
        ["xcrun", "-sdk", "macosx", "metallib", str(build / "shader.air"), "-o", str(build / "default.metallib")],
        ["xcrun", "swiftc", "-O", "-parse-as-library", str(build / "Renderer.swift"), "-o", str(build / "check")],
    ]
    for command in commands:
        subprocess.run(command, check=True)
    run = [str(build / "check"), str(args.output.resolve())]
    if args.swift_source is None:
        run.append("--verify-reuse")
    result = subprocess.run(run, check=True, text=True, capture_output=True)
    print(result.stdout, end="")
    (args.output / "timings.txt").write_text(result.stdout)

if args.compare:
    frames = list(args.compare.glob("*.bgra"))
    if not frames:
        raise SystemExit("No baseline frames found")
    for baseline in frames:
        current = args.output / baseline.name
        if baseline.read_bytes() != current.read_bytes():
            raise SystemExit(f"Pixel mismatch: {baseline.name}")
    print(f"Pixel parity passed for {len(frames)} scenarios")
