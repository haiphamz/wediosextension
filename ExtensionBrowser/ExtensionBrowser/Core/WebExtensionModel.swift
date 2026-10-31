//
//  WebExtensionModel.swift
//  ExtensionBrowser
//
//  Mô hình dữ liệu cho WebExtension (Chrome Manifest V2 & V3)
//

import Foundation
import UIKit

public enum ExtensionRunAt: String, Codable {
    case documentStart = "document_start"
    case documentEnd = "document_end"
    case documentIdle = "document_idle"
}

public struct ContentScriptRule: Codable, Identifiable {
    public var id = UUID()
    public let matches: [String]
    public let js: [String]?
    public let css: [String]?
    public let runAt: ExtensionRunAt

    enum CodingKeys: String, CodingKey {
        case matches
        case js
        case css
        case runAt = "run_at"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        matches = try container.decode([String].self, forKey: .matches)
        js = try container.decodeIfPresent([String].self, forKey: .js)
        css = try container.decodeIfPresent([String].self, forKey: .css)
        runAt = (try? container.decodeIfPresent(ExtensionRunAt.self, forKey: .runAt)) ?? .documentEnd
    }
}

public struct ExtensionManifest: Codable {
    public let manifestVersion: Int
    public let name: String
    public let version: String
    public let description: String?
    public let icons: [String: String]?
    public let contentScripts: [ContentScriptRule]?
    public let permissions: [String]?

    // Manifest V2
    public let browserAction: ActionConfig?
    // Manifest V3
    public let action: ActionConfig?

    public struct ActionConfig: Codable {
        public let defaultPopup: String?
        public let defaultTitle: String?
        public let defaultIcon: String? // có thể là string hoặc dictionary, handled below

        enum CodingKeys: String, CodingKey {
            case defaultPopup = "default_popup"
            case defaultTitle = "default_title"
            case defaultIcon = "default_icon"
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            defaultPopup = try container.decodeIfPresent(String.self, forKey: .defaultPopup)
            defaultTitle = try container.decodeIfPresent(String.self, forKey: .defaultTitle)
            
            // Xử lý defaultIcon nếu là string hoặc dictionary
            if let iconStr = try? container.decodeIfPresent(String.self, forKey: .defaultIcon) {
                defaultIcon = iconStr
            } else if let iconDict = try? container.decodeIfPresent([String: String].self, forKey: .defaultIcon) {
                defaultIcon = iconDict.values.first
            } else {
                defaultIcon = nil
            }
        }
    }

    enum CodingKeys: String, CodingKey {
        case manifestVersion = "manifest_version"
        case name
        case version
        case description
        case icons
        case contentScripts = "content_scripts"
        case permissions
        case browserAction = "browser_action"
        case action
    }

    public var effectivePopup: String? {
        return action?.defaultPopup ?? browserAction?.defaultPopup
    }

    public var effectiveTitle: String? {
        return action?.defaultTitle ?? browserAction?.defaultTitle ?? name
    }

    public var effectiveIconPath: String? {
        if let icon = action?.defaultIcon ?? browserAction?.defaultIcon {
            return icon
        }
        if let icons = icons {
            if let maxIcon = icons["128"] ?? icons["60"] ?? icons["48"] ?? icons["16"] {
                return maxIcon
            }
            return icons.values.first
        }
        return nil
    }
}

public class WebExtension: Identifiable, ObservableObject {
    public let id: String
    public let folderURL: URL
    public let manifest: ExtensionManifest

    @Published public var isEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isEnabled, forKey: "ext_enabled_\(id)")
        }
    }

    public var name: String { manifest.name }
    public var version: String { manifest.version }
    public var description: String { manifest.description ?? "" }
    public var popupURL: URL? {
        guard let popupPath = manifest.effectivePopup else { return nil }
        return folderURL.appendingPathComponent(popupPath)
    }

    public var iconImage: UIImage? {
        if let iconPath = manifest.effectiveIconPath {
            let iconURL = folderURL.appendingPathComponent(iconPath)
            if let data = try? Data(contentsOf: iconURL), let img = UIImage(data: data) {
                return img
            }
        }
        return UIImage(systemName: "puzzlepiece.extension.fill")
    }

    public init(id: String, folderURL: URL, manifest: ExtensionManifest) {
        self.id = id
        self.folderURL = folderURL
        self.manifest = manifest
        let savedState = UserDefaults.standard.object(forKey: "ext_enabled_\(id)") as? Bool
        self.isEnabled = savedState ?? true
    }
}
