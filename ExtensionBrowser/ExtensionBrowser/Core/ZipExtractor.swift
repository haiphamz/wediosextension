//
//  ZipExtractor.swift
//  ExtensionBrowser
//
//  Giải nén tệp .zip tự động vào thư mục đích (sử dụng zlib tích hợp của iOS)
//

import Foundation
import zlib

public class ZipExtractor {
    public enum ZipError: Error {
        case fileNotFound
        case invalidZipHeader
        case decompressionFailed
    }

    public static func extract(zipURL: URL, to destinationURL: URL) throws {
        let fileData = try Data(contentsOf: zipURL)
        let fileManager = FileManager.default

        var offset = 0
        let totalSize = fileData.count

        while offset + 30 <= totalSize {
            let sig = fileData.subdata(in: offset..<offset+4).withUnsafeBytes { $0.load(as: UInt32.self) }
            
            // Local file header signature: 0x04034b50
            if sig != 0x04034b50 {
                break // Đã tới Central Directory hoặc kết thúc
            }

            let compMethod = fileData.subdata(in: offset+8..<offset+10).withUnsafeBytes { $0.load(as: UInt16.self) }
            let compSize = Int(fileData.subdata(in: offset+18..<offset+22).withUnsafeBytes { $0.load(as: UInt32.self) })
            let uncompSize = Int(fileData.subdata(in: offset+22..<offset+26).withUnsafeBytes { $0.load(as: UInt32.self) })
            let nameLen = Int(fileData.subdata(in: offset+26..<offset+28).withUnsafeBytes { $0.load(as: UInt16.self) })
            let extraLen = Int(fileData.subdata(in: offset+28..<offset+30).withUnsafeBytes { $0.load(as: UInt16.self) })

            offset += 30
            guard offset + nameLen <= totalSize else { break }

            let nameData = fileData.subdata(in: offset..<offset+nameLen)
            let filename = String(data: nameData, encoding: .utf8) ?? String(data: nameData, encoding: .ascii) ?? "file"
            offset += nameLen + extraLen

            guard offset + compSize <= totalSize else { break }
            let compressedData = fileData.subdata(in: offset..<offset+compSize)
            offset += compSize

            let targetURL = destinationURL.appendingPathComponent(filename)

            if filename.hasSuffix("/") {
                // Thư mục
                try? fileManager.createDirectory(at: targetURL, withIntermediateDirectories: true)
            } else {
                // Tệp tin
                let parentDir = targetURL.deletingLastPathComponent()
                try? fileManager.createDirectory(at: parentDir, withIntermediateDirectories: true)

                if compMethod == 0 {
                    // Không nén (STORE)
                    try compressedData.write(to: targetURL)
                } else if compMethod == 8 {
                    // DEFLATE (zlib inflate)
                    if let decompressed = inflateData(compressedData, expectedSize: uncompSize) {
                        try decompressed.write(to: targetURL)
                    }
                }
            }
        }
    }

    private static func inflateData(_ data: Data, expectedSize: Int) -> Data? {
        var stream = z_stream()
        var status = inflateInit2_(&stream, -MAX_WBITS, ZLIB_VERSION, Int32(MemoryLayout<z_stream>.size))
        guard status == Z_OK else { return nil }

        defer { inflateEnd(&stream) }

        var decompressed = Data(count: max(expectedSize, data.count * 2))
        
        data.withUnsafeBytes { inputBytes in
            stream.next_in = UnsafeMutablePointer<Bytef>(mutating: inputBytes.bindMemory(to: Bytef.self).baseAddress)
            stream.avail_in = uInt(data.count)

            repeat {
                if Int(stream.total_out) >= decompressed.count {
                    decompressed.count += max(expectedSize, 4096)
                }

                decompressed.withUnsafeMutableBytes { outBytes in
                    stream.next_out = outBytes.bindMemory(to: Bytef.self).baseAddress?.advanced(by: Int(stream.total_out))
                    stream.avail_out = uInt(decompressed.count - Int(stream.total_out))
                    status = inflate(&stream, Z_NO_FLUSH)
                }
            } while status == Z_OK
        }

        guard status == Z_STREAM_END else { return nil }
        decompressed.count = Int(stream.total_out)
        return decompressed
    }
}
