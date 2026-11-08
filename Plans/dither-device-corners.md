# Dither: hide squares under device corners

> **Historical.** A note on a change that was made.

## Request
Adon asked for the dither grid to know the device's screen corner radius and not draw squares that would be cut off by the rounded corners. Squares should follow the curve with as little padding as possible.

## Context found
- The grid is the Metal dither renderer in `Ergo/Views/Other Views/Dither/` (`DitherView.swift`, `OptimizedDither.metal`). It is used by the library detail views, `CanvasBackdrop` and `AboutView`.
- Cell size is `pixelSize * (drawable px / points)`. `columns = width / cell` and `rows = height / cell` use integer division, and the grid is centred in the drawable (`padding = (viewport - grid) / 2`). So the only squares being clipped were the ones at the screen's rounded corners.
- Every render path (fused compute, separate cell pass, upscale, atlas, cell blur) gets its per-cell colour from `quantizedCellColor` in the shader. Alpha 0 means the cell is "off" (the background colour, or transparent).
- `LibraryGridView` (the category cards) is unrelated.

## What changed
`OptimizedDither.metal`
- `DitherUniforms` gained `screenOrigin`, `screenSize` and `screenCornerRadius`, appended at the end.
- New `cellOutsideDeviceCorners(cell, uniforms)` recomputes the cell's pixel rect from the centred padding. It tests the cell's four corners against a rounded-rectangle signed distance function of the screen, and returns true if any corner is outside.
- `quantizedCellColor` sets `alpha = 0` for those cells. This covers every render path.

`DitherView.swift`
- The Swift `DitherUniforms` mirrors the new fields.
- `DitherRenderInputs` gained `screenOrigin`, `screenSize` and `screenCornerRadius`, in points.
- `DitherConfiguration.clipsToDeviceCorners` (default `true`) turns the behaviour on or off.
- `render` multiplies the screen values by the pixel scale and zeroes the radius when the flag is off.
- `DitherHostView.applyDeviceCorners(to:)` runs each frame on iOS. It reads the radius from `cornerProbe`, an empty view that fills the window with `.corners(radius: .containerConcentric())`, via `effectiveRadius(corner:)`. It converts `screen.bounds` into the view's coordinates with `screen.coordinateSpace.convert`.

## Behaviour notes
- Views that don't touch the screen corners are unaffected, because their cells all lie inside the rounded rectangle.
- Offscreen renders and macOS pass a radius of 0, so nothing is hidden.
- The test uses the whole cell box, not the gap-inset square. That is slightly conservative but never clips.

## Risks and open points
- `effectiveRadius(corner:)` is public, but no doc promises that a view concentric with the window resolves to the display's radius. If it resolves to 0 the grid draws normally, with squares clipped by the corners as before. The alternative is a per-model table of radii.
- Any change to `DitherUniforms` must also update the size check in `DitherMetalRenderer.init` (now 144), or every render fails and the dither doesn't show.
- Hidden cells in `colorPlacement == "background"` or theme-colour modes were not checked visually.

## Verification
- An `xcodebuild` Debug-style build of the `Ergo` scheme for iOS Simulator succeeded. It used a scratchpad `-derivedDataPath` because Xcode held the default build database lock.
- Nothing was run on a simulator or device, per the project rules. The visual result is untested.
- Git was not touched.
