# StillDock 1.0.0 validation

Validation date: 2026-09-12. Build 1. Native runtime host: Apple silicon, macOS 26.6 (25G72), Xcode 26.6. Minimum deployment target: macOS 14.

## Verified core behavior

`DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test` passed 20 XCTest cases with zero failures and zero skips in 6.721 seconds.

- Source GPS, camera, capture-time, author, editorial, XMP and PNG text fixtures prove private values are present before export and absent afterward.
- Orientation 1–8 is tested against independent expected pixel layouts, including mirrored images.
- Maximum edge preserves aspect ratio and never upscales small images.
- HEIC input was actually generated and decoded on this host; that test did not skip.
- PNG alpha and partially transparent pixels remain; JPEG composites transparency onto white.
- Exporting to an existing filename, the original's filename, or a dangling symlink leaves existing data intact.
- Twelve concurrent exports choose distinct filenames without replacing each other.
- Unsafe filenames cannot escape the destination; invalid options and destinations fail.
- Unreadable, unsupported, incomplete and multi-frame inputs are rejected where the decoder reports them invalid.
- Oversized PNG dimensions, an input exceeding 512 MiB, and FIFO input are rejected before unsafe processing.

Every successful export is read back from disk and checked against the encoded bytes, image format, dimensions and metadata policy. The output verifier permits only narrow technical EXIF values newly synthesized by ImageIO: sRGB color space and matching pixel dimensions. It does not permit source capture data.

## Independent review and corrections

An independent reviewer found no unresolved release-blocking core defect. Review led to nonblocking final-file reopen and regular-file verification, plus stronger source-fixture assertions. A native launch test found a dynamic library signing mismatch that compile checks had missed; the core is now statically linked while hardened runtime remains enabled.

Apple's ImageIO can salvage a damaged JPEG whose entropy data ends early. An independent synthetic probe confirmed this. The app and README advise inspecting the preview and exported copy; output validation does not claim the original was intact.

## Native app QA

The real Mac app was opened and inspected through its native accessibility interface and screenshots. File chooser import and separate-directory batch export were exercised with synthetic images.

- A JPEG with GPS/EXIF and a portrait PNG were imported. The GPS indicator appeared on the original.
- JPEG 1920 px export produced two files at 1920×1280 and 1536×1920, with success indicators and output sizes.
- The PNG control and 1280 px preset were selected in the UI; export produced 1280×853 and 1024×1280 PNGs in a new folder.
- One synthetic source was temporarily moved out of reach. The next batch saved the other image and reported exactly one success and one failure; dismissing the error banner retained that failure summary. The source was restored afterward.
- SHA-256 verification confirmed all three original fixtures remained unchanged.
- Clear returned the app to its empty state and disabled export. The final application was installed in Applications, reopened, and used to export a synthetic JPEG successfully.
- An independent Pillow decoder fully loaded the five exported files and inspected EXIF sub-IFDs. JPEG and PNG contained only synthesized color-space and dimension EXIF fields. JPEG's Photoshop resources were an empty IPTC payload and its empty-payload digest, confirmed separately.

The chooser was changed to an asynchronous sheet after the initial nested modal implementation interfered with UI automation. Native file-row selection through generic click/keyboard actions was unreliable in the automation interface; the chooser's exposed Open Finder item action succeeded. Actual multi-selection by mouse, drag-and-drop and between-file cancellation remain unverified on this host.

## Coverage boundaries

The app is built for arm64 and x86_64. Native execution is verified on Apple silicon only; Intel execution and macOS 14 execution require those environments. Peak memory near the input limits, deliberately expanded compressed metadata and injected disk-full failures are not measured by this suite. No real personal photos were used in QA.

## Release evidence

See the release's attached receipt for the final artifact hashes, native UI result, signing identity, notarization response and downloaded-file verification. A successful build alone does not establish notarization or public availability.
