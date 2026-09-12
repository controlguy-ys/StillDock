StillDock helps prepare sharing copies of photos on your Mac. Originals stay intact; select JPEG or PNG, set a maximum edge and export to a separate folder with a metadata recheck.

**Developer preview: ad hoc signed, not notarized.** Gatekeeper may block a downloaded copy. Developer ID certificate issuance and Apple notarization are pending. This is not an App Store or notarized release.

- macOS 14+, universal arm64/x86_64 build. Native execution tested on Apple silicon with macOS 26.6.
- 20 core tests passed, including HEIC, all eight orientations, alpha, metadata fixtures, original hashes and concurrent no-overwrite exports.
- Native JPEG/PNG export, partial failure reporting and reset were exercised. Exported files were independently decoded and checked.
- No account, ads, analytics or network requests.

Photos' visible faces and text remain. Output uses 8-bit sRGB SDR; JPEG is recompressed, and files can become larger. Some damaged sources may be salvaged by Apple's decoder; inspect the preview and exported copy. See the full [validation record](https://github.com/controlguy-ys/StillDock/blob/main/docs/validation.md).

The DMG filename explicitly identifies its unnotarized state. SHA256SUMS and release-receipt.json describe the exact artifacts.
