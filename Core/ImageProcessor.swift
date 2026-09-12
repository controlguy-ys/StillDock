import CoreGraphics
import Darwin
import Foundation
import ImageIO
import UniformTypeIdentifiers

public enum ExportFormat: String, CaseIterable, Sendable {
    case jpeg, png

    public var fileExtension: String { self == .jpeg ? "jpg" : "png" }
    public var displayName: String { self == .jpeg ? "JPEG" : "PNG" }
    fileprivate var typeIdentifier: CFString { (self == .jpeg ? UTType.jpeg.identifier : UTType.png.identifier) as CFString }
}

public struct ExportOptions: Sendable {
    public var format: ExportFormat
    public var maxPixelSize: Int?
    public var jpegQuality: Double

    public init(format: ExportFormat = .jpeg, maxPixelSize: Int? = 1920, jpegQuality: Double = 0.85) {
        self.format = format
        self.maxPixelSize = maxPixelSize
        self.jpegQuality = jpegQuality
    }
}

public struct ImageInspection: Sendable {
    public let url: URL
    public let inputBytes: Int64
    /// Display dimensions, with the source orientation applied.
    public let width: Int
    public let height: Int
    public let metadataGroups: [String]
}

public struct ExportResult: Sendable {
    public let outputURL: URL
    public let inputBytes: Int64
    public let outputBytes: Int64
    public let width: Int
    public let height: Int
    public let metadataVerified: Bool
}

public enum ImageProcessingError: LocalizedError {
    case invalidInput
    case unsupportedFormat
    case multipleFrames
    case imageTooLarge
    case invalidOptions
    case decodeFailed
    case encodeFailed
    case verificationFailed
    case invalidDestination
    case fileOperation(String)

    public var errorDescription: String? {
        switch self {
        case .invalidInput: return "The file could not be read as a regular local image."
        case .unsupportedFormat: return "Choose a JPEG, PNG, or HEIC/HEIF still image."
        case .multipleFrames: return "Animated and multi-frame images are not supported. Export a single still image first."
        case .imageTooLarge: return "This image exceeds the 100-megapixel or 512 MB input limit."
        case .invalidOptions: return "Choose a positive maximum edge and a JPEG quality between 0 and 1."
        case .decodeFailed: return "The image is damaged or could not be fully decoded."
        case .encodeFailed: return "A new image could not be encoded."
        case .verificationFailed: return "The exported image did not pass the dimensions and metadata check."
        case .invalidDestination: return "Choose an existing, writable output folder."
        case .fileOperation(let detail): return "The export could not be saved: \(detail)"
        }
    }
}

/// Stateless image processing. Call from a background task; each call owns its decoder and buffers.
public struct ImageProcessor: Sendable {
    public static let maximumInputPixels = 100_000_000
    public static let maximumInputBytes: Int64 = 512 * 1024 * 1024

    public init() {}

    public func inspect(_ url: URL) throws -> ImageInspection {
        let loaded = try load(url)
        // Decode a small thumbnail so header-only and damaged inputs do not look ready.
        _ = try decodedImage(loaded.source, maximumEdge: min(256, max(loaded.width, loaded.height)))
        return ImageInspection(url: url, inputBytes: Int64(loaded.data.count), width: loaded.width,
                               height: loaded.height, metadataGroups: metadataGroups(loaded.source, properties: loaded.properties))
    }

    /// The supplied filename is a stem. An extension and a collision suffix are added automatically.
    /// Commits use the kernel's exclusive rename, so existing files and symlinks are never overwritten.
    public func export(inputURL: URL, to directory: URL, filename: String = "photo",
                       options: ExportOptions = .init()) throws -> ExportResult {
        guard options.jpegQuality.isFinite, (0...1).contains(options.jpegQuality),
              options.maxPixelSize.map({ $0 > 0 }) ?? true else { throw ImageProcessingError.invalidOptions }
        let loaded = try load(inputURL)
        let sourceEdge = max(loaded.width, loaded.height)
        let edge = min(options.maxPixelSize ?? sourceEdge, sourceEdge)
        let decoded = try decodedImage(loaded.source, maximumEdge: edge)
        guard decoded.width <= edge, decoded.height <= edge,
              decoded.width > 0, decoded.height > 0 else { throw ImageProcessingError.decodeFailed }

        // The new sRGB pixel buffer is the privacy boundary. No source property dictionary,
        // metadata object, thumbnail, or auxiliary image is passed to the destination encoder.
        let raster = try freshRaster(decoded, flattenAlpha: options.format == .jpeg)
        let encoded = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(encoded, options.format.typeIdentifier, 1, nil) else {
            throw ImageProcessingError.encodeFailed
        }
        var properties: [CFString: Any] = [:]
        if options.format == .jpeg { properties[kCGImageDestinationLossyCompressionQuality] = options.jpegQuality }
        CGImageDestinationAddImage(destination, raster, properties as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { throw ImageProcessingError.encodeFailed }
        let data = encoded as Data
        try verify(data, format: options.format, width: raster.width, height: raster.height)

        let outputURL = try saveExclusively(data, directory: directory, stem: safeStem(filename),
                                          format: options.format, width: raster.width, height: raster.height)
        return ExportResult(outputURL: outputURL, inputBytes: Int64(loaded.data.count), outputBytes: Int64(data.count),
                            width: raster.width, height: raster.height, metadataVerified: true)
    }

    private struct LoadedImage {
        let data: Data
        let source: CGImageSource
        let width: Int
        let height: Int
        let properties: [String: Any]
    }

    private func load(_ url: URL) throws -> LoadedImage {
        guard url.isFileURL else { throw ImageProcessingError.invalidInput }
        // Nonblocking prevents a named pipe from hanging the importer before fstat rejects it.
        let descriptor = open(url.path, O_RDONLY | O_NONBLOCK | O_CLOEXEC)
        guard descriptor >= 0 else { throw ImageProcessingError.invalidInput }
        defer { close(descriptor) }
        var info = stat()
        guard fstat(descriptor, &info) == 0, (info.st_mode & S_IFMT) == S_IFREG, info.st_size > 0 else {
            throw ImageProcessingError.invalidInput
        }
        guard info.st_size <= Self.maximumInputBytes else { throw ImageProcessingError.imageTooLarge }
        let data = try readAll(descriptor, maximumBytes: Self.maximumInputBytes)
        try preflightPNGDimensions(data)
        guard let source = CGImageSourceCreateWithData(data as CFData, [kCGImageSourceShouldCache: false] as CFDictionary) else {
            throw ImageProcessingError.decodeFailed
        }
        guard let type = CGImageSourceGetType(source) as String?,
              [UTType.jpeg.identifier, UTType.png.identifier, UTType.heic.identifier, UTType.heif.identifier].contains(type) else {
            throw ImageProcessingError.unsupportedFormat
        }
        guard CGImageSourceGetCount(source) == 1 else { throw ImageProcessingError.multipleFrames }
        guard CGImageSourceGetStatus(source) == .statusComplete,
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any],
              let width = (properties[kCGImagePropertyPixelWidth as String] as? NSNumber)?.intValue,
              let height = (properties[kCGImagePropertyPixelHeight as String] as? NSNumber)?.intValue,
              width > 0, height > 0 else { throw ImageProcessingError.decodeFailed }
        // Division avoids overflow for malicious dimensions.
        guard width <= Self.maximumInputPixels / height else { throw ImageProcessingError.imageTooLarge }
        let orientation = (properties[kCGImagePropertyOrientation as String] as? NSNumber)?.intValue ?? 1
        let swapsAxes = (5...8).contains(orientation)
        return LoadedImage(data: data, source: source, width: swapsAxes ? height : width,
                           height: swapsAxes ? width : height, properties: properties)
    }

    private func preflightPNGDimensions(_ data: Data) throws {
        let signature: [UInt8] = [137, 80, 78, 71, 13, 10, 26, 10]
        guard data.count >= 24, data.prefix(8).elementsEqual(signature) else { return }
        // PNG's fixed first IHDR lets us enforce the allocation limit before ImageIO
        // parses ancillary chunks or tries to recover a malformed oversized image.
        guard data[8..<16].elementsEqual([0, 0, 0, 13, 73, 72, 68, 82]) else {
            throw ImageProcessingError.decodeFailed
        }
        let width = data[16..<20].reduce(UInt64(0)) { ($0 << 8) | UInt64($1) }
        let height = data[20..<24].reduce(UInt64(0)) { ($0 << 8) | UInt64($1) }
        guard width > 0, height > 0 else { throw ImageProcessingError.decodeFailed }
        guard width <= UInt64(Self.maximumInputPixels) / height else { throw ImageProcessingError.imageTooLarge }
    }

    private func decodedImage(_ source: CGImageSource, maximumEdge: Int) throws -> CGImage {
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maximumEdge,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceShouldAllowFloat: false
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary),
              CGImageSourceGetStatusAtIndex(source, 0) == .statusComplete else { throw ImageProcessingError.decodeFailed }
        return image
    }

    private func freshRaster(_ image: CGImage, flattenAlpha: Bool) throws -> CGImage {
        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(data: nil, width: image.width, height: image.height, bitsPerComponent: 8,
                                      bytesPerRow: 0, space: colorSpace,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
            throw ImageProcessingError.decodeFailed
        }
        let bounds = CGRect(x: 0, y: 0, width: image.width, height: image.height)
        if flattenAlpha {
            context.setFillColor(CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 1))
            context.fill(bounds)
        }
        context.interpolationQuality = .high
        context.draw(image, in: bounds)
        guard let result = context.makeImage() else { throw ImageProcessingError.decodeFailed }
        return result
    }

    private func metadataGroups(_ source: CGImageSource, properties: [String: Any]) -> [String] {
        let technicalGroups: Set<String> = ["{JFIF}", "{PNG}", "{Exif}"]
        var groups = Set(properties.keys.filter { $0.hasPrefix("{") && !technicalGroups.contains($0) }
            .map { $0.trimmingCharacters(in: CharacterSet(charactersIn: "{}")) })
        if let png = properties["{PNG}"] as? [String: Any], !Set(png.keys).isSubset(of: Self.allowedPNGKeys) {
            groups.insert("PNG text")
        }
        if let exif = properties["{Exif}"] as? [String: Any],
           !exif.allSatisfy({ technicalExifValue(name: $0.key, value: $0.value, properties: properties) }) {
            groups.insert("Exif")
        }
        if let metadata = CGImageSourceCopyMetadataAtIndex(source, 0, nil),
           let tags = CGImageMetadataCopyTags(metadata) as? [CGImageMetadataTag],
           tags.contains(where: { tag in
               guard (CGImageMetadataTagCopyNamespace(tag) as String?) == "http://ns.adobe.com/exif/1.0/",
                     let name = CGImageMetadataTagCopyName(tag) as String?,
                     let value = CGImageMetadataTagCopyValue(tag) else { return true }
               return !technicalExifValue(name: name, value: value, properties: properties)
           }), groups.isEmpty {
            groups.insert("Embedded tags")
        }
        return groups.sorted()
    }

    /// ImageIO synthesizes these three fields from the fresh sRGB raster on current macOS.
    /// They are permitted only with the exact technical values, never copied capture information.
    private func technicalExifValue(name: String, value: Any, properties: [String: Any]) -> Bool {
        let expected: Int?
        switch name {
        case "ColorSpace": expected = 1
        case "PixelXDimension": expected = (properties["PixelWidth"] as? NSNumber)?.intValue
        case "PixelYDimension": expected = (properties["PixelHeight"] as? NSNumber)?.intValue
        default: return false
        }
        guard let expected else { return false }
        if let number = value as? NSNumber { return number.doubleValue == Double(expected) }
        if let string = value as? String { return string == String(expected) }
        return false
    }

    private static let allowedPNGKeys: Set<String> = ["InterlaceType", "Gamma", "Chromaticities", "sRGBIntent", "XPixelsPerMeter", "YPixelsPerMeter"]
    private static let allowedTopLevelKeys: Set<String> = [
        "PixelWidth", "PixelHeight", "Depth", "ColorModel", "ProfileName", "HasAlpha", "IsFloat", "IsIndexed",
        "DPIWidth", "DPIHeight", "{JFIF}", "{PNG}", "{Exif}"
    ]

    private func verify(_ data: Data, format: ExportFormat, width: Int, height: Int) throws {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              CGImageSourceGetType(source) == format.typeIdentifier,
              CGImageSourceGetCount(source) == 1,
              CGImageSourceGetStatus(source) == .statusComplete,
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any],
              Set(properties.keys).isSubset(of: Self.allowedTopLevelKeys),
              metadataGroups(source, properties: properties).isEmpty,
              (properties[kCGImagePropertyPixelWidth as String] as? NSNumber)?.intValue == width,
              (properties[kCGImagePropertyPixelHeight as String] as? NSNumber)?.intValue == height,
              let decoded = CGImageSourceCreateImageAtIndex(source, 0, [kCGImageSourceShouldCacheImmediately: true] as CFDictionary),
              decoded.width == width, decoded.height == height,
              CGImageSourceGetStatusAtIndex(source, 0) == .statusComplete else {
            throw ImageProcessingError.verificationFailed
        }
    }

    private func safeStem(_ filename: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        let sanitized = filename.unicodeScalars.map { allowed.contains($0) ? String($0) : "-" }.joined()
        let trimmed = sanitized.trimmingCharacters(in: CharacterSet(charactersIn: "-_"))
        return trimmed.isEmpty ? "photo" : String(trimmed.prefix(60))
    }

    private func saveExclusively(_ data: Data, directory: URL, stem: String,
                                 format: ExportFormat, width: Int, height: Int) throws -> URL {
        guard directory.isFileURL else { throw ImageProcessingError.invalidDestination }
        let directoryFD = open(directory.path, O_RDONLY | O_DIRECTORY | O_CLOEXEC)
        guard directoryFD >= 0 else { throw ImageProcessingError.invalidDestination }
        defer { close(directoryFD) }
        let temporaryName = ".stilldock-\(UUID().uuidString).part"
        let temporaryFD = openat(directoryFD, temporaryName, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW | O_CLOEXEC, 0o600)
        guard temporaryFD >= 0 else { throw fileError() }
        defer {
            close(temporaryFD)
            unlinkat(directoryFD, temporaryName, 0)
        }
        try data.withUnsafeBytes { bytes in
            guard let base = bytes.baseAddress else { throw ImageProcessingError.encodeFailed }
            var written = 0
            while written < bytes.count {
                let count = Darwin.write(temporaryFD, base.advanced(by: written), bytes.count - written)
                if count < 0 && errno == EINTR { continue }
                guard count > 0 else { throw fileError() }
                written += count
            }
        }
        guard fsync(temporaryFD) == 0 else { throw fileError() }
        var originalInfo = stat()
        guard fstat(temporaryFD, &originalInfo) == 0 else { throw fileError() }

        for sequence in 1...100_000 {
            let suffix = sequence == 1 ? "" : "-\(sequence)"
            let name = "\(stem)\(suffix).\(format.fileExtension)"
            guard renameatx_np(directoryFD, temporaryName, directoryFD, name, UInt32(RENAME_EXCL)) == 0 else {
                if errno == EEXIST || errno == ENOTEMPTY { continue }
                throw fileError()
            }
            let finalFD = openat(directoryFD, name, O_RDONLY | O_NOFOLLOW | O_NONBLOCK | O_CLOEXEC)
            guard finalFD >= 0 else { throw ImageProcessingError.verificationFailed }
            defer { close(finalFD) }
            var finalInfo = stat()
            guard fstat(finalFD, &finalInfo) == 0, (finalInfo.st_mode & S_IFMT) == S_IFREG,
                  finalInfo.st_dev == originalInfo.st_dev,
                  finalInfo.st_ino == originalInfo.st_ino, finalInfo.st_size == data.count else {
                throw ImageProcessingError.verificationFailed
            }
            let reopened = try readAll(finalFD, maximumBytes: Int64(data.count))
            guard reopened == data else { throw ImageProcessingError.verificationFailed }
            try verify(reopened, format: format, width: width, height: height)
            return directory.appendingPathComponent(name)
        }
        throw ImageProcessingError.fileOperation("Too many files already use this name.")
    }

    private func readAll(_ descriptor: Int32, maximumBytes: Int64) throws -> Data {
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 64 * 1024)
        while true {
            let count = Darwin.read(descriptor, &buffer, buffer.count)
            if count < 0 && errno == EINTR { continue }
            guard count >= 0 else { throw fileError() }
            if count == 0 { return data }
            guard Int64(data.count) + Int64(count) <= maximumBytes else { throw ImageProcessingError.imageTooLarge }
            data.append(contentsOf: buffer.prefix(count))
        }
    }

    private func fileError() -> ImageProcessingError {
        let code = errno
        return .fileOperation(String(cString: strerror(code)))
    }
}
