import CoreGraphics
import CryptoKit
import Darwin
import Foundation
import ImageIO
import UniformTypeIdentifiers
import XCTest
@testable import StillDockCore

final class ImageProcessorTests: XCTestCase {
    private var directory: URL!
    private let processor = ImageProcessor()

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent("StillDockTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
    }

    override func tearDownWithError() throws {
        if let directory { try FileManager.default.removeItem(at: directory) }
    }

    func testFreshJPEGRemovesLocationCameraAndEditorialMetadataAndPreservesOriginal() throws {
        let input = try fixture(name: "private.jpg", type: UTType.jpeg.identifier, width: 80, height: 40, properties: [
            kCGImagePropertyGPSDictionary: [kCGImagePropertyGPSLatitude: 37.5, kCGImagePropertyGPSLatitudeRef: "N",
                                          kCGImagePropertyGPSLongitude: 127.0, kCGImagePropertyGPSLongitudeRef: "E"],
            kCGImagePropertyExifDictionary: [kCGImagePropertyExifUserComment: "PRIVATE-TEST-SECRET",
                                           kCGImagePropertyExifDateTimeOriginal: "2026:09:12 12:00:00"],
            kCGImagePropertyIPTCDictionary: [kCGImagePropertyIPTCCaptionAbstract: "PRIVATE-TEST-SECRET"],
            kCGImagePropertyTIFFDictionary: [kCGImagePropertyTIFFArtist: "PRIVATE-TEST-SECRET"]
        ])
        let original = try Data(contentsOf: input)
        let beforeHash = SHA256.hash(data: original)
        let sourceProperties = try propertiesAtURL(input)
        let sourceGPS = try XCTUnwrap(sourceProperties["{GPS}"] as? [String: Any])
        XCTAssertEqual((sourceGPS["Latitude"] as? NSNumber)?.doubleValue, 37.5)
        let sourceExif = try XCTUnwrap(sourceProperties["{Exif}"] as? [String: Any])
        XCTAssertEqual(sourceExif["UserComment"] as? String, "PRIVATE-TEST-SECRET")
        XCTAssertEqual(sourceExif["DateTimeOriginal"] as? String, "2026:09:12 12:00:00")
        let inspection = try processor.inspect(input)
        XCTAssertTrue(inspection.metadataGroups.contains("GPS"))
        XCTAssertTrue(inspection.metadataGroups.contains("Exif"))
        XCTAssertTrue(inspection.metadataGroups.contains("IPTC"))

        for format in ExportFormat.allCases {
            let result = try processor.export(inputURL: input, to: directory, options: .init(format: format))
            XCTAssertTrue(result.metadataVerified)
            XCTAssertEqual(result.width, 80)
            XCTAssertEqual(result.height, 40)
            XCTAssertEqual(result.inputBytes, Int64(original.count))
            let output = try Data(contentsOf: result.outputURL)
            XCTAssertEqual(result.outputBytes, Int64(output.count))
            XCTAssertNil(output.range(of: Data("PRIVATE-TEST-SECRET".utf8)))
            XCTAssertTrue(try processor.inspect(result.outputURL).metadataGroups.isEmpty)
            let outputProperties = try propertiesAtURL(result.outputURL)
            XCTAssertNil(outputProperties["{GPS}"])
            XCTAssertNil(outputProperties["{IPTC}"])
            XCTAssertNil(outputProperties["{TIFF}"])
            if let technical = outputProperties["{Exif}"] as? [String: Any] {
                XCTAssertTrue(Set(technical.keys).isSubset(of: ["ColorSpace", "PixelXDimension", "PixelYDimension"]))
                if let color = technical["ColorSpace"] as? NSNumber { XCTAssertEqual(color.intValue, 1) }
                if let width = technical["PixelXDimension"] as? NSNumber { XCTAssertEqual(width.intValue, result.width) }
                if let height = technical["PixelYDimension"] as? NSNumber { XCTAssertEqual(height.intValue, result.height) }
            }
        }
        XCTAssertEqual(beforeHash, SHA256.hash(data: try Data(contentsOf: input)))
    }

    func testXMPIsRemoved() throws {
        let input = try fixture(name: "xmp.jpg", type: UTType.jpeg.identifier, width: 16, height: 8)
        var data = try Data(contentsOf: input)
        // Inject a standard XMP APP1 fixture directly: ImageIO may discard CreatorTool when
        // synthesizing test files, which would make a marker-removal test pass vacuously.
        let packet = """
        <x:xmpmeta xmlns:x="adobe:ns:meta/"><rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"><rdf:Description rdf:about="" xmlns:xmp="http://ns.adobe.com/xap/1.0/" xmp:CreatorTool="PRIVATE-XMP-SECRET"/></rdf:RDF></x:xmpmeta>
        """
        var payload = Data("http://ns.adobe.com/xap/1.0/\0".utf8)
        payload.append(Data(packet.utf8))
        let length = payload.count + 2
        var segment = Data([0xFF, 0xE1, UInt8(length >> 8), UInt8(length & 255)])
        segment.append(payload)
        data.insert(contentsOf: segment, at: 2)
        try data.write(to: input)
        XCTAssertNotNil(data.range(of: Data("PRIVATE-XMP-SECRET".utf8)))
        let source = try XCTUnwrap(CGImageSourceCreateWithData(data as CFData, nil))
        let metadata = try XCTUnwrap(CGImageSourceCopyMetadataAtIndex(source, 0, nil))
        XCTAssertEqual(CGImageMetadataCopyStringValueWithPath(metadata, nil, "xmp:CreatorTool" as CFString) as String?, "PRIVATE-XMP-SECRET")
        XCTAssertFalse(try processor.inspect(input).metadataGroups.isEmpty)
        let result = try processor.export(inputURL: input, to: directory)
        XCTAssertTrue(try processor.inspect(result.outputURL).metadataGroups.isEmpty)
        XCTAssertNil(try Data(contentsOf: result.outputURL).range(of: Data("PRIVATE-XMP-SECRET".utf8)))
    }

    func testOrientationAppliedOnceAndNotUpscaled() throws {
        let input = try fixture(name: "rotated.png", type: UTType.png.identifier, width: 4, height: 2,
                                properties: [kCGImagePropertyOrientation: 6])
        let inspection = try processor.inspect(input)
        XCTAssertEqual(inspection.width, 2)
        XCTAssertEqual(inspection.height, 4)
        let result = try processor.export(inputURL: input, to: directory, options: .init(format: .png, maxPixelSize: 1920))
        XCTAssertEqual(result.width, 2)
        XCTAssertEqual(result.height, 4)
        let pixels = try pixelsAtURL(result.outputURL)
        XCTAssertEqual(Array(pixels.prefix(8)), [0, 0, 255, 255, 255, 0, 0, 255])
        // Exporting the already-normalized output must not rotate it for a second time.
        let second = try processor.export(inputURL: result.outputURL, to: directory, options: .init(format: .png, maxPixelSize: nil))
        XCTAssertEqual(try pixelsAtURL(second.outputURL), pixels)
    }

    func testAspectRatioAndMaximumEdge() throws {
        let input = try fixture(name: "wide.png", width: 120, height: 60)
        let result = try processor.export(inputURL: input, to: directory, options: .init(format: .png, maxPixelSize: 48))
        XCTAssertEqual(result.width, 48)
        XCTAssertEqual(result.height, 24)
    }

    func testAllEightOrientationsMatchIndependentPixelExpectations() throws {
        let red: [UInt8] = [255, 0, 0, 255], green: [UInt8] = [0, 255, 0, 255]
        let blue: [UInt8] = [0, 0, 255, 255], yellow: [UInt8] = [255, 255, 0, 255]
        let expected = [
            [red, red, green, green, blue, blue, yellow, yellow],
            [green, green, red, red, yellow, yellow, blue, blue],
            [yellow, yellow, blue, blue, green, green, red, red],
            [blue, blue, yellow, yellow, red, red, green, green],
            [red, blue, red, blue, green, yellow, green, yellow],
            [blue, red, blue, red, yellow, green, yellow, green],
            [yellow, green, yellow, green, blue, red, blue, red],
            [green, yellow, green, yellow, red, blue, red, blue]
        ]
        for orientation in 1...8 {
            let input = try fixture(name: "orientation-\(orientation).png", width: 4, height: 2,
                                    properties: [kCGImagePropertyOrientation: orientation])
            let result = try processor.export(inputURL: input, to: directory, options: .init(format: .png, maxPixelSize: nil))
            XCTAssertEqual(result.width, orientation >= 5 ? 2 : 4)
            XCTAssertEqual(result.height, orientation >= 5 ? 4 : 2)
            XCTAssertEqual(try pixelsAtURL(result.outputURL), expected[orientation - 1].flatMap { $0 }, "Orientation \(orientation)")
        }
    }

    func testHEICStillInHEIFContainerCanBeInspectedAndExported() throws {
        let destinations = CGImageDestinationCopyTypeIdentifiers() as? [String] ?? []
        try XCTSkipUnless(destinations.contains(UTType.heic.identifier), "This macOS runtime does not provide a HEIC encoder.")
        let input = try fixture(name: "still.heic", type: UTType.heic.identifier, width: 64, height: 32,
                                properties: [kCGImagePropertyOrientation: 6])
        let originalHash = SHA256.hash(data: try Data(contentsOf: input))
        let inspection = try processor.inspect(input)
        XCTAssertEqual(inspection.width, 32)
        XCTAssertEqual(inspection.height, 64)
        for format in ExportFormat.allCases {
            let output = try processor.export(inputURL: input, to: directory, options: .init(format: format, maxPixelSize: 32))
            XCTAssertEqual(output.width, 16)
            XCTAssertEqual(output.height, 32)
            XCTAssertTrue(output.metadataVerified)
        }
        XCTAssertEqual(originalHash, SHA256.hash(data: try Data(contentsOf: input)))
    }

    func testPartialAlphaIsPreservedForPNGAndCompositedForJPEG() throws {
        let input = directory.appendingPathComponent("partial-alpha.png")
        let destination = try XCTUnwrap(CGImageDestinationCreateWithURL(input as CFURL, UTType.png.identifier as CFString, 1, nil))
        let halfRed = [[UInt8]](repeating: [128, 0, 0, 128], count: 32 * 32).flatMap { $0 }
        let provider = try XCTUnwrap(CGDataProvider(data: Data(halfRed) as CFData))
        let source = try XCTUnwrap(CGImage(width: 32, height: 32, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: 128,
                                          space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                          bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                                          provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent))
        CGImageDestinationAddImage(destination, source, nil)
        XCTAssertTrue(CGImageDestinationFinalize(destination))
        let png = try processor.export(inputURL: input, to: directory, options: .init(format: .png))
        XCTAssertEqual(Array(try pixelsAtURL(png.outputURL).prefix(4)), [128, 0, 0, 128])
        let jpeg = try processor.export(inputURL: input, to: directory, options: .init(format: .jpeg, jpegQuality: 1))
        let pixel = Array(try pixelsAtURL(jpeg.outputURL).prefix(4))
        XCTAssertGreaterThanOrEqual(pixel[0], 253)
        XCTAssertTrue((125...129).contains(Int(pixel[1])))
        XCTAssertTrue((125...129).contains(Int(pixel[2])))
        XCTAssertEqual(pixel[3], 255)
    }

    func testPNGTextIsDetectedAndRemoved() throws {
        let input = try fixture(name: "text.png", width: 16, height: 8, properties: [
            kCGImagePropertyPNGDictionary: [kCGImagePropertyPNGDescription: "PRIVATE-PNG-SECRET",
                                           kCGImagePropertyPNGAuthor: "PRIVATE-PNG-AUTHOR"]
        ])
        let source = try Data(contentsOf: input)
        XCTAssertNotNil(source.range(of: Data("PRIVATE-PNG-SECRET".utf8)))
        XCTAssertTrue(try processor.inspect(input).metadataGroups.contains("PNG text"))
        let output = try processor.export(inputURL: input, to: directory, options: .init(format: .png))
        XCTAssertNil(try Data(contentsOf: output.outputURL).range(of: Data("PRIVATE-PNG-SECRET".utf8)))
        XCTAssertTrue(try processor.inspect(output.outputURL).metadataGroups.isEmpty)
    }

    func testOriginalSizeAndPNGAlpha() throws {
        let input = try fixture(name: "transparent.png", width: 20, height: 10, transparent: true)
        let png = try processor.export(inputURL: input, to: directory, options: .init(format: .png, maxPixelSize: nil))
        XCTAssertEqual(png.width, 20)
        XCTAssertEqual(png.height, 10)
        XCTAssertEqual(try pixelsAtURL(png.outputURL)[3], 0)
        let jpeg = try processor.export(inputURL: input, to: directory, options: .init(format: .jpeg, maxPixelSize: nil, jpegQuality: 1))
        let whitePixel = Array(try pixelsAtURL(jpeg.outputURL).prefix(4))
        XCTAssertTrue(whitePixel.prefix(3).allSatisfy { $0 >= 250 }, "Transparent JPEG corner should flatten on white: \(whitePixel)")
        XCTAssertEqual(whitePixel[3], 255)
    }

    func testExistingFilesAndDanglingSymlinksAreNeverOverwritten() throws {
        let input = try fixture(name: "input.png", width: 8, height: 4)
        let existing = directory.appendingPathComponent("photo.png")
        let sentinel = Data("existing-file-do-not-touch".utf8)
        try sentinel.write(to: existing)
        let absentTarget = directory.appendingPathComponent("absent.png")
        let symlink = directory.appendingPathComponent("photo-2.png")
        try FileManager.default.createSymbolicLink(at: symlink, withDestinationURL: absentTarget)
        let result = try processor.export(inputURL: input, to: directory, options: .init(format: .png))
        XCTAssertEqual(result.outputURL.lastPathComponent, "photo-3.png")
        XCTAssertEqual(try Data(contentsOf: existing), sentinel)
        XCTAssertEqual(try FileManager.default.destinationOfSymbolicLink(atPath: symlink.path), absentTarget.path)
        XCTAssertFalse(FileManager.default.fileExists(atPath: absentTarget.path))
        XCTAssertFalse(try FileManager.default.contentsOfDirectory(atPath: directory.path).contains { $0.hasSuffix(".part") })
    }

    func testExportToOriginalNameDoesNotOverwriteOriginal() throws {
        let input = try fixture(name: "photo.png", width: 8, height: 4)
        let originalHash = SHA256.hash(data: try Data(contentsOf: input))
        let result = try processor.export(inputURL: input, to: directory, options: .init(format: .png))
        XCTAssertEqual(result.outputURL.lastPathComponent, "photo-2.png")
        XCTAssertEqual(originalHash, SHA256.hash(data: try Data(contentsOf: input)))
    }

    func testParallelExportsChooseUniqueNamesWithoutClobbering() async throws {
        let input = try fixture(name: "input.png", width: 64, height: 32)
        let folder = directory!
        let outputs = try await withThrowingTaskGroup(of: ExportResult.self) { group in
            for _ in 0..<12 {
                group.addTask { try ImageProcessor().export(inputURL: input, to: folder, options: .init(format: .png)) }
            }
            var results: [ExportResult] = []
            for try await result in group { results.append(result) }
            return results
        }
        XCTAssertEqual(Set(outputs.map(\.outputURL)).count, 12)
        for result in outputs { XCTAssertTrue(try processor.inspect(result.outputURL).metadataGroups.isEmpty) }
        XCTAssertFalse(try FileManager.default.contentsOfDirectory(atPath: directory.path).contains { $0.hasSuffix(".part") })
    }

    func testUnsafeStemCannotEscapeOutputFolder() throws {
        let input = try fixture(name: "input.png", width: 8, height: 4)
        let result = try processor.export(inputURL: input, to: directory, filename: "../../unsafe/name", options: .init(format: .png))
        XCTAssertEqual(result.outputURL.deletingLastPathComponent().standardizedFileURL, directory.standardizedFileURL)
        XCTAssertFalse(result.outputURL.lastPathComponent.hasPrefix("."))
        XCTAssertFalse(result.outputURL.lastPathComponent.contains("/"))
    }

    func testCorruptInputRejectedWithoutOutput() throws {
        let input = directory.appendingPathComponent("corrupt.jpg")
        try Data("not an image".utf8).write(to: input)
        XCTAssertThrowsError(try processor.inspect(input))
        XCTAssertThrowsError(try processor.export(inputURL: input, to: directory))
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: directory.path), ["corrupt.jpg"])
    }

    func testTruncatedJPEGRejected() throws {
        let input = try fixture(name: "truncated.jpg", type: UTType.jpeg.identifier, width: 256, height: 128)
        let data = try Data(contentsOf: input)
        try data.prefix(data.count / 2).write(to: input)
        XCTAssertThrowsError(try processor.export(inputURL: input, to: directory))
    }

    func testAnimatedPNGRejected() throws {
        let input = directory.appendingPathComponent("animated.png")
        let data = NSMutableData()
        let destination = try XCTUnwrap(CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 2, nil))
        let animation: [CFString: Any] = [kCGImagePropertyPNGDictionary: [kCGImagePropertyAPNGDelayTime: 0.1]]
        for _ in 0..<2 { CGImageDestinationAddImage(destination, try makeImage(width: 8, height: 4), animation as CFDictionary) }
        XCTAssertTrue(CGImageDestinationFinalize(destination))
        try (data as Data).write(to: input)
        let source = try XCTUnwrap(CGImageSourceCreateWithURL(input as CFURL, nil))
        XCTAssertEqual(CGImageSourceGetCount(source), 2)
        XCTAssertThrowsError(try processor.export(inputURL: input, to: directory)) { error in
            guard case ImageProcessingError.multipleFrames = error else { return XCTFail("Wrong error: \(error)") }
        }
    }

    func testUnsupportedTIFFRejected() throws {
        let input = try fixture(name: "input.tiff", type: UTType.tiff.identifier, width: 8, height: 4)
        XCTAssertThrowsError(try processor.inspect(input)) { error in
            guard case ImageProcessingError.unsupportedFormat = error else { return XCTFail("Wrong error: \(error)") }
        }
    }

    func testInvalidOptionsAndDestinationRejected() throws {
        let input = try fixture(name: "input.png", width: 8, height: 4)
        for options in [ExportOptions(maxPixelSize: 0), ExportOptions(jpegQuality: .nan), ExportOptions(jpegQuality: 1.1)] {
            XCTAssertThrowsError(try processor.export(inputURL: input, to: directory, options: options))
        }
        XCTAssertThrowsError(try processor.export(inputURL: input, to: directory.appendingPathComponent("missing")))
    }

    func testOversizedPNGHeaderIsRejectedBeforePixelAllocation() throws {
        let input = try fixture(name: "oversized.png", width: 8, height: 4)
        var data = try Data(contentsOf: input)
        // A valid PNG IHDR checksum makes the decoder see the dimensions; the pixel limit
        // must be checked before it attempts to allocate the declared >100-megapixel raster.
        data.replaceSubrange(16..<24, with: [0, 0, 0x27, 0x11, 0, 0, 0x27, 0x10])
        let checksum = crc32(Data(data[12..<29]))
        data.replaceSubrange(29..<33, with: [UInt8(checksum >> 24), UInt8((checksum >> 16) & 255),
                                            UInt8((checksum >> 8) & 255), UInt8(checksum & 255)])
        try data.write(to: input)
        XCTAssertThrowsError(try processor.inspect(input)) { error in
            guard case ImageProcessingError.imageTooLarge = error else { return XCTFail("Wrong error: \(error)") }
        }
    }

    func testSparseOversizedFileAndFIFOAreRejectedWithoutReading() throws {
        let large = directory.appendingPathComponent("oversized.jpg")
        XCTAssertTrue(FileManager.default.createFile(atPath: large.path, contents: Data()))
        let handle = try FileHandle(forWritingTo: large)
        try handle.truncate(atOffset: UInt64(ImageProcessor.maximumInputBytes + 1))
        try handle.close()
        XCTAssertThrowsError(try processor.inspect(large)) { error in
            guard case ImageProcessingError.imageTooLarge = error else { return XCTFail("Wrong error: \(error)") }
        }
        let pipe = directory.appendingPathComponent("pipe.png")
        XCTAssertEqual(mkfifo(pipe.path, 0o600), 0)
        XCTAssertThrowsError(try processor.inspect(pipe)) { error in
            guard case ImageProcessingError.invalidInput = error else { return XCTFail("Wrong error: \(error)") }
        }
    }

    // MARK: Synthetic fixtures only

    private func fixture(name: String, type: String = UTType.png.identifier, width: Int, height: Int,
                         properties: [CFString: Any] = [:], transparent: Bool = false) throws -> URL {
        let url = directory.appendingPathComponent(name)
        let destination = try XCTUnwrap(CGImageDestinationCreateWithURL(url as CFURL, type as CFString, 1, nil))
        CGImageDestinationAddImage(destination, try makeImage(width: width, height: height, transparent: transparent), properties as CFDictionary)
        XCTAssertTrue(CGImageDestinationFinalize(destination))
        return url
    }

    private func makeImage(width: Int, height: Int, transparent: Bool = false) throws -> CGImage {
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        for y in 0..<height {
            for x in 0..<width {
                let color: [UInt8]
                if transparent && x < width / 2 { color = [0, 0, 0, 0] }
                else if y < height / 2 { color = x < width / 2 ? [255, 0, 0, 255] : [0, 255, 0, 255] }
                else { color = x < width / 2 ? [0, 0, 255, 255] : [255, 255, 0, 255] }
                pixels.replaceSubrange(((y * width + x) * 4)..<((y * width + x) * 4 + 4), with: color)
            }
        }
        let provider = try XCTUnwrap(CGDataProvider(data: Data(pixels) as CFData))
        return try XCTUnwrap(CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32,
                                    bytesPerRow: width * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                    bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                                    provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent))
    }

    private func pixelsAtURL(_ url: URL) throws -> [UInt8] {
        let source = try XCTUnwrap(CGImageSourceCreateWithURL(url as CFURL, nil))
        let image = try XCTUnwrap(CGImageSourceCreateImageAtIndex(source, 0, nil))
        var pixels = [UInt8](repeating: 0, count: image.width * image.height * 4)
        try pixels.withUnsafeMutableBytes { bytes in
            let context = try XCTUnwrap(CGContext(data: bytes.baseAddress, width: image.width, height: image.height,
                                                bitsPerComponent: 8, bytesPerRow: image.width * 4,
                                                space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
            context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        }
        return pixels
    }

    private func propertiesAtURL(_ url: URL) throws -> [String: Any] {
        let source = try XCTUnwrap(CGImageSourceCreateWithURL(url as CFURL, nil))
        return try XCTUnwrap(CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any])
    }

    private func crc32(_ data: Data) -> UInt32 {
        var crc = UInt32.max
        for byte in data {
            crc ^= UInt32(byte)
            for _ in 0..<8 { crc = (crc >> 1) ^ (crc & 1 == 0 ? 0 : 0xEDB88320) }
        }
        return ~crc
    }
}
