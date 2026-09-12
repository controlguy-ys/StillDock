# StillDock

Native macOS 14+ photo export utility. Work only inside this project.
Preserve originals; exports must never overwrite existing files.
Use ImageIO/CoreGraphics for a fresh pixel encode. Never copy source metadata.
No networking, analytics, account, cloud service, or third-party runtime dependency.
Only JPEG, PNG, and HEIC/HEIF still input; reject multi-frame input.
All success claims require reopening and validating the output.
Use synthetic fixtures, never personal photos, for QA and screenshots.
Run `swift test` with full Xcode DEVELOPER_DIR, build the app, and exercise real UI before release.
Do not commit signing keys, tokens, keychain data, local paths, or generated binary artifacts.
Record release notes in docs/releases.json. Distribution is authorized by the user's original request.
