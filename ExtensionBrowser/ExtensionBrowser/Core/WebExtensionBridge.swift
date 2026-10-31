//
//  WebExtensionBridge.swift
//  ExtensionBrowser
//
//  Cầu nối giữa WKWebView và Native Swift cho Chrome Storage & Runtime Message
//

import Foundation
import WebKit

/// Tránh retain cycle giữa WKUserContentController và ScriptMessageHandler
public class ScriptLeakAvoider: NSObject, WKScriptMessageHandler {
    private weak var delegate: WKScriptMessageHandler?

    public init(delegate: WKScriptMessageHandler) {
        self.delegate = delegate
        super.init()
    }

    public func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        delegate?.userContentController(userContentController, didReceive: message)
    }
}

public class WebExtensionBridge: NSObject, WKScriptMessageHandler {
    public static let shared = WebExtensionBridge()

    public weak var mainWebView: WKWebView?
    public weak var popupWebView: WKWebView?

    public override init() {
        super.init()
    }

    public func attach(to configuration: WKWebViewConfiguration, isPopup: Bool = false) {
        let contentController = configuration.userContentController

        // Gỡ bỏ handler cũ nếu có
        contentController.removeScriptMessageHandler(forName: "nativeStorage")
        contentController.removeScriptMessageHandler(forName: "chromeRuntime")

        let leakAvoider = ScriptLeakAvoider(delegate: self)
        contentController.add(leakAvoider, name: "nativeStorage")
        contentController.add(leakAvoider, name: "chromeRuntime")
    }

    public func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        if message.name == "nativeStorage" {
            handleNativeStorage(body: message.body)
        } else if message.name == "chromeRuntime" {
            handleChromeRuntime(body: message.body)
        }
    }

    // MARK: - Xử lý Native Storage
    private func handleNativeStorage(body: Any) {
        var rawData = "{}"
        var extId = "sc-crossfader-default"
        var area = "local"

        if let dict = body as? [String: Any] {
            if let d = dict["data"] as? String { rawData = d }
            if let e = dict["extensionId"] as? String { extId = e }
            if let a = dict["area"] as? String { area = a }
        } else if let str = body as? String {
            rawData = str
        }

        // 1. Lưu vĩnh viễn vào UserDefaults
        UserDefaults.standard.set(rawData, forKey: "ext_storage_\(extId)_\(area)")
        // Lưu tương thích ngược cho SoundCloud
        UserDefaults.standard.set(rawData, forKey: "sc_cue_storage")

        print("[WebExtensionBridge] Đã lưu storage vào UserDefaults cho ext: \(extId)")

        // 2. Phát tán thông báo thay đổi tới Main Webview và Popup Webview
        let escapedData = rawData.replacingOccurrences(of: "\\", with: "\\\\")
                                 .replacingOccurrences(of: "'", with: "\\'")
                                 .replacingOccurrences(of: "\n", with: "\\n")

        let dispatchScript = """
        try {
            if (window.__dispatchStorageChangeFromNative) {
                window.__dispatchStorageChangeFromNative('\(escapedData)', '\(area)');
            }
            window.dispatchEvent(new Event('storage'));
        } catch(e) {}
        """

        DispatchQueue.main.async {
            self.mainWebView?.evaluateJavaScript(dispatchScript, completionHandler: nil)
            self.popupWebView?.evaluateJavaScript(dispatchScript, completionHandler: nil)
        }
    }

    // MARK: - Xử lý Chrome Runtime Message
    private func handleChromeRuntime(body: Any) {
        guard let dict = body as? [String: Any],
              let type = dict["type"] as? String else { return }

        if type == "TAB_SEND_MESSAGE" || type == "RUNTIME_SEND_MESSAGE" {
            if let payload = dict["payload"],
               let jsonData = try? JSONSerialization.data(withJSONObject: payload),
               let jsonString = String(data: jsonData, encoding: .utf8) {
                
                let escapedJson = jsonString.replacingOccurrences(of: "\\", with: "\\\\")
                                            .replacingOccurrences(of: "'", with: "\\'")

                let script = "try { window.__dispatchRuntimeMessageFromNative('\(escapedJson)'); } catch(e){}"

                DispatchQueue.main.async {
                    if type == "TAB_SEND_MESSAGE" {
                        self.mainWebView?.evaluateJavaScript(script, completionHandler: nil)
                    } else {
                        self.mainWebView?.evaluateJavaScript(script, completionHandler: nil)
                        self.popupWebView?.evaluateJavaScript(script, completionHandler: nil)
                    }
                }
            }
        } else if type == "OPEN_POPUP" {
            // Mở popup được trigger từ extension script
            NotificationCenter.default.post(name: NSNotification.Name("OpenExtensionPopupNotification"), object: dict["extensionId"])
        }
    }
}
