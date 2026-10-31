//
//  WebExtensionManager.swift
//  ExtensionBrowser
//
//  Quản lý cài đặt, kích hoạt, giải nén và nạp Chrome/WebExtension
//

import Foundation
import UIKit
import Combine

public class WebExtensionManager: ObservableObject {
    public static let shared = WebExtensionManager()

    @Published public var extensions: [WebExtension] = []
    @Published public var isPickerPresented = false
    @Published public var statusMessage: String? = nil

    private let fileManager = FileManager.default

    public var extensionsDirectory: URL {
        let docs = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let extDir = docs.appendingPathComponent("Extensions", isDirectory: true)
        if !fileManager.fileExists(atPath: extDir.path) {
            try? fileManager.createDirectory(at: extDir, withIntermediateDirectories: true)
        }
        return extDir
    }

    public init() {
        copyBundledDefaultExtensionIfNeeded()
        loadInstalledExtensions()
    }

    /// Sao chép Extension mặc định (SoundCloud Crossfader) từ App Bundle vào Documents nếu chưa có
    public func copyBundledDefaultExtensionIfNeeded() {
        let defaultTargetDir = extensionsDirectory.appendingPathComponent("soundcloud_cue", isDirectory: true)
        
        // Nếu đã có thì không cần chép đè
        if fileManager.fileExists(atPath: defaultTargetDir.appendingPathComponent("manifest.json").path) {
            return
        }

        // Tìm trong Bundle
        if let bundleDir = Bundle.main.url(forResource: "soundcloud_cue", withExtension: nil) ??
           Bundle.main.url(forResource: "DefaultExtensions/soundcloud_cue", withExtension: nil) {
            try? fileManager.copyItem(at: bundleDir, to: defaultTargetDir)
            print("[WebExtensionManager] Đã sao chép Default Extension từ Bundle.")
        }
    }

    /// Quét và nạp toàn bộ extension đã cài trong Documents/Extensions
    public func loadInstalledExtensions() {
        var loaded: [WebExtension] = []
        guard let items = try? fileManager.contentsOfDirectory(at: extensionsDirectory, includingPropertiesForKeys: [.isDirectoryKey], options: .skipsHiddenFiles) else {
            DispatchQueue.main.async { self.extensions = [] }
            return
        }

        for folderURL in items {
            let manifestURL = folderURL.appendingPathComponent("manifest.json")
            if fileManager.fileExists(atPath: manifestURL.path),
               let data = try? Data(contentsOf: manifestURL),
               let manifest = try? JSONDecoder().decode(ExtensionManifest.self, from: data) {
                let id = folderURL.lastPathComponent
                let ext = WebExtension(id: id, folderURL: folderURL, manifest: manifest)
                loaded.append(ext)
            }
        }

        DispatchQueue.main.async {
            self.extensions = loaded
            print("[WebExtensionManager] Đã nạp thành công \(loaded.count) extensions.")
        }
    }

    /// Cài đặt Extension từ tệp .zip do người dùng chọn từ Files
    public func installExtension(fromZipURL zipURL: URL) {
        let tempExtractDir = fileManager.temporaryDirectory.appendingPathComponent("ext_temp_\(UUID().uuidString)")
        try? fileManager.createDirectory(at: tempExtractDir, withIntermediateDirectories: true)

        defer {
            try? fileManager.removeItem(at: tempExtractDir)
        }

        do {
            // 1. Giải nén ZIP
            try ZipExtractor.extract(zipURL: zipURL, to: tempExtractDir)

            // 2. Tìm file manifest.json (kể cả khi bị lồng trong thư mục con)
            var manifestFolder = tempExtractDir
            let enumerator = fileManager.enumerator(at: tempExtractDir, includingPropertiesForKeys: nil)
            while let file = enumerator?.nextObject() as? URL {
                if file.lastPathComponent.lowercased() == "manifest.json" {
                    manifestFolder = file.deletingLastPathComponent()
                    break
                }
            }

            let manifestURL = manifestFolder.appendingPathComponent("manifest.json")
            guard fileManager.fileExists(atPath: manifestURL.path) else {
                showStatus("Không tìm thấy tệp manifest.json trong file zip!")
                return
            }

            let manifestData = try Data(contentsOf: manifestURL)
            let manifest = try JSONDecoder().decode(ExtensionManifest.self, from: manifestData)

            // 3. Tạo thư mục đích trong Documents/Extensions
            let safeName = manifest.name.replacingOccurrences(of: " ", with: "_").lowercased()
            let finalFolder = extensionsDirectory.appendingPathComponent(safeName)
            if fileManager.fileExists(atPath: finalFolder.path) {
                try? fileManager.removeItem(at: finalFolder)
            }

            try fileManager.copyItem(at: manifestFolder, to: finalFolder)

            // Đảm bảo có sẵn extension_bridge.js trong thư mục extension
            let bridgeDest = finalFolder.appendingPathComponent("extension_bridge.js")
            if !fileManager.fileExists(atPath: bridgeDest.path),
               let bundledBridge = Bundle.main.url(forResource: "extension_bridge", withExtension: "js") {
                try? fileManager.copyItem(at: bundledBridge, to: bridgeDest)
            }

            loadInstalledExtensions()
            showStatus("Đã cài đặt Extension: \(manifest.name) v\(manifest.version)")
        } catch {
            print("[WebExtensionManager] Lỗi cài đặt Extension:", error)
            showStatus("Lỗi cài đặt: \(error.localizedDescription)")
        }
    }

    /// Xóa Extension khỏi máy
    public func deleteExtension(_ ext: WebExtension) {
        try? fileManager.removeItem(at: ext.folderURL)
        loadInstalledExtensions()
        showStatus("Đã gỡ cài đặt: \(ext.name)")
    }

    private func showStatus(_ msg: String) {
        DispatchQueue.main.async {
            self.statusMessage = msg
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                if self.statusMessage == msg {
                    self.statusMessage = nil
                }
            }
        }
    }

    /// Lấy danh sách JavaScript cần inject cho URL đang duyệt
    public func getScriptsToInject(for url: URL, runAt: ExtensionRunAt) -> [String] {
        var scripts: [String] = []

        // Khi ở documentStart, luôn nạp bridge API trước tiên
        if runAt == .documentStart {
            if let bridgeURL = Bundle.main.url(forResource: "extension_bridge", withExtension: "js") ??
               Bundle.main.url(forResource: "Scripts/extension_bridge", withExtension: "js"),
               let bridgeCode = try? String(contentsOf: bridgeURL, encoding: .utf8) {
                scripts.append(bridgeCode)
            }
        }

        // Duyệt qua các extension đang bật
        for ext in extensions where ext.isEnabled {
            guard let contentScripts = ext.manifest.contentScripts else { continue }
            for rule in contentScripts {
                guard rule.runAt == runAt else { continue }
                if MatchPattern.matchesAny(patterns: rule.matches, url: url) {
                    if let jsFiles = rule.js {
                        for jsName in jsFiles {
                            let scriptURL = ext.folderURL.appendingPathComponent(jsName)
                            if let code = try? String(contentsOf: scriptURL, encoding: .utf8) {
                                // Bọc trong context có manifest & id
                                let wrapped = """
                                (() => {
                                  window.__EXTENSION_ID__ = "\(ext.id)";
                                  \(code)
                                })();
                                """
                                scripts.append(wrapped)
                            }
                        }
                    }
                }
            }
        }

        return scripts
    }

    /// Lấy CSS cần inject cho URL đang duyệt
    public func getCSSToInject(for url: URL) -> [String] {
        var cssList: [String] = []
        for ext in extensions where ext.isEnabled {
            guard let contentScripts = ext.manifest.contentScripts else { continue }
            for rule in contentScripts {
                if MatchPattern.matchesAny(patterns: rule.matches, url: url) {
                    if let cssFiles = rule.css {
                        for cssName in cssFiles {
                            let cssURL = ext.folderURL.appendingPathComponent(cssName)
                            if let style = try? String(contentsOf: cssURL, encoding: .utf8) {
                                cssList.append(style)
                            }
                        }
                    }
                }
            }
        }
        return cssList
    }

    /// Lấy extension có popup khả dụng cho trang hiện tại
    public func getActivePopupExtensions(for url: URL?) -> [WebExtension] {
        return extensions.filter { ext in
            ext.isEnabled && ext.popupURL != nil
        }
    }
}
