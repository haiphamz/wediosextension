//
//  ExtensionPopupView.swift
//  ExtensionBrowser
//
//  Khung hiển thị giao diện Popup của Extension (popup.html)
//

import SwiftUI
import WebKit

public struct ExtensionPopupView: View {
    public let `extension`: WebExtension
    @Environment(\.presentationMode) var presentationMode

    public var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                if let popupURL = `extension`.popupURL {
                    PopupWebViewRepresentable(popupURL: popupURL, extensionId: `extension`.id)
                } else {
                    Text("Extension này không có giao diện popup.")
                        .foregroundColor(.gray)
                        .padding()
                }
            }
            .navigationBarTitle(`extension`.name, displayMode: .inline)
            .navigationBarItems(trailing: Button("Đóng") {
                presentationMode.wrappedValue.dismiss()
            })
        }
    }
}

public struct PopupWebViewRepresentable: UIViewRepresentable {
    public let popupURL: URL
    public let extensionId: String

    public func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.preferences.javaScriptCanOpenWindowsAutomatically = true
        WebExtensionBridge.shared.attach(to: config, isPopup: true)

        let webView = WKWebView(frame: .zero, configuration: config)
        WebExtensionBridge.shared.popupWebView = webView
        webView.navigationDelegate = context.coordinator

        // Load popup file
        let readAccessURL = popupURL.deletingLastPathComponent()
        webView.loadFileURL(popupURL, allowingReadAccessTo: readAccessURL)

        return webView
    }

    public func updateUIView(_ uiView: WKWebView, context: Context) {}

    public func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    public class Coordinator: NSObject, WKNavigationDelegate {
        var parent: PopupWebViewRepresentable

        init(_ parent: PopupWebViewRepresentable) {
            self.parent = parent
        }

        public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            // Nạp storage từ UserDefaults vào localStorage của popup
            let savedStorage = UserDefaults.standard.string(forKey: "sc_cue_storage") ?? "{}"
            let escaped = savedStorage.replacingOccurrences(of: "\\", with: "\\\\")
                                      .replacingOccurrences(of: "'", with: "\\'")
            let initStorageScript = """
            try {
                localStorage.setItem('sc_cue_storage', '\(escaped)');
                localStorage.setItem('__ext_storage_\(self.parent.extensionId)_local', '\(escaped)');
                window.dispatchEvent(new Event('storage'));
            } catch(e){}
            """
            webView.evaluateJavaScript(initStorageScript, completionHandler: nil)
        }
    }
}
