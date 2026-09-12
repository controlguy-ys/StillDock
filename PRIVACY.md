# Privacy

StillDock processes files locally on your Mac. It does not send images, metadata, filenames, diagnostics or usage data to a server. There are no accounts, advertisements or analytics SDKs.

The app reads images you select and writes copies to the output folder you select. Originals are kept intact. It retains no application history or image library after you close it. Your exported files remain in the folder you chose.

An output is rendered into a fresh 8-bit sRGB pixel buffer, encoded as JPEG or PNG, then reopened and checked for unexpected metadata. Source GPS, EXIF, IPTC and XMP information is not copied. Technical image fields, including dimensions, compression and a generic color profile, remain.

This is not image redaction. Visible faces, addresses, screenshots and text remain in the image. File-system creation times and information added by other applications are outside the embedded metadata check. If you choose an iCloud Drive or other synchronized output folder, its provider may upload the exports according to your own settings; StillDock does not control that service.

For issues, use the repository issue tracker. Do not attach private photos or location information; a synthetic example and the error message are usually enough.
