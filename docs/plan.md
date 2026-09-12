# StillDock 1.0

## Product
A small native Mac workbench for preparing photos for sharing: add a batch, select JPEG or PNG and a maximum edge, then export fresh copies with no copied GPS, EXIF, IPTC, or XMP information. Original files remain untouched. The result view reports dimensions, bytes and a metadata recheck.

## Scope
- macOS 14+, SwiftUI/AppKit, ImageIO/CoreGraphics, offline.
- JPEG, PNG, HEIC/HEIF still input; JPEG/PNG output.
- Drop or choose multiple files, thumbnail list, batch statistics, remove/reset.
- Maximum edge presets: original size, 2560, 1920, 1280; no upscaling.
- JPEG quality control; transparent input flattens on white for JPEG.
- New output subfolder and neutral sequential file names by default.
- Sequential background processing, per-file errors, between-file cancellation.
- Reopen outputs to verify dimensions and absence of sensitive metadata groups.
- File-size reduction is measured, never guaranteed. Visible image content is unchanged apart from conversion/resize; faces and text remain.

## Delivery
Developer ID signed and Apple-notarized universal macOS app in a DMG, GitHub release with checksums and installation instructions. If Apple account capability blocks signing, retain exact evidence and ship no misleading ready claim.

## Verification
Synthetic GPS/EXIF/IPTC fixtures, orientation, PNG transparency, aspect ratio, no upscaling, corrupt input, multi-frame rejection, collisions, output metadata, originals hashes. Native UI checks: empty state, import, presets, export, failure handling, reset. Independent code review after build.

## Work allocation
Core engine and core tests: core worker. UI and app state: UI worker. Project configuration, build, release tooling, packaging, runtime QA and integration: root. Research: research worker.

## Run sizing
recommended_tier: frontier
recommended_effort: thorough
rationale: Product selection and public release cross design, image fidelity, data preservation and signing boundaries.
move_up_if: Unresolved source preservation or release security assumptions require deeper deliberation; specialized platform behavior exceeds the current capability.
move_down_if: Stable interfaces and passing independent acceptance checks make subsequent changes mechanical; then reduce capability and effort.
proof_surface: Image fixtures, source hashes, actual native UI, universal release build, signature, notarization and downloaded artifact hash.
