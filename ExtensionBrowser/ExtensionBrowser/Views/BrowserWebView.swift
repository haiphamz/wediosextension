//
//  BrowserWebView.swift
//  ExtensionBrowser
//
//  Trình duyệt web WKWebView tích hợp nạp Extension, hỗ trợ âm thanh nền & Desktop Mode
//

import SwiftUI
import WebKit
import AVFoundation

public struct BrowserWebView: UIViewRepresentable {
    @ObservedObject public var extensionManager = WebExtensionManager.shared
    @Binding public var currentURLString: String
    @Binding public var webTitle: String
    @Binding public var canGoBack: Bool
    @Binding public var canGoForward: Bool
    @Binding public var isLoading: Bool
    @Binding public var progress: Double
    @Binding public var isDesktopMode: Bool

    public var loadURLRequest: URLRequest?
    public var triggerReload: Bool
    public var triggerBack: Bool
    public var triggerForward: Bool

    public static let desktopUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15"
    public static let mobileUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1"

    public func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    public func makeUIView(context: Context) -> WKWebView {
        // Cấu hình âm thanh nền để không bị ngắt nhạc
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers, .allowAirPlay])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("[BrowserWebView] Lỗi cấu hình AVAudioSession:", error)
        }

        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = true

        // Gắn Native Storage & Runtime bridge
        WebExtensionBridge.shared.attach(to: configuration, isPopup: false)

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        webView.customUserAgent = isDesktopMode ? Self.desktopUserAgent : Self.mobileUserAgent

        WebExtensionBridge.shared.mainWebView = webView

        // Quan sát tiến trình tải trang (estimatedProgress)
        context.coordinator.setupProgressObserver(for: webView)

        // Tải trang khởi đầu
        if let request = loadURLRequest {
            webView.load(request)
        } else if let initialURL = URL(string: "https://soundcloud.com/discover") {
            webView.load(URLRequest(url: initialURL))
        }

        return webView
    }

    public func updateUIView(_ webView: WKWebView, context: Context) {
        // Cập nhật User Agent nếu đổi Desktop / Mobile
        let desiredUA = isDesktopMode ? Self.desktopUserAgent : Self.mobileUserAgent
        if webView.customUserAgent != desiredUA {
            webView.customUserAgent = desiredUA
            webView.reload()
        }

        // Xử lý lệnh điều hướng
        if triggerBack && webView.canGoBack {
            webView.goBack()
        }
        if triggerForward && webView.canGoForward {
            webView.goForward()
        }
        if triggerReload {
            webView.reload()
        }

        if let request = loadURLRequest, webView.url?.absoluteString != request.url?.absoluteString {
            webView.load(request)
        }
    }

    // MARK: - Coordinator (Navigation & UI Delegate)
    public class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        var parent: BrowserWebView
        private var progressObservation: NSKeyValueObservation?

        init(_ parent: BrowserWebView) {
            self.parent = parent
        }

        func setupProgressObserver(for webView: WKWebView) {
            progressObservation = webView.observe(\.estimatedProgress, options: [.new]) { [weak self] wv, _ in
                DispatchQueue.main.async {
                    self?.parent.progress = wv.estimatedProgress
                }
            }
        }

        deinit {
            progressObservation?.invalidate()
        }

        // 1. Khi bắt đầu điều hướng
        public func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            DispatchQueue.main.async {
                self.parent.isLoading = true
                if let url = webView.url {
                    self.parent.currentURLString = url.absoluteString
                }
            }
        }

        // 2. Khi bắt đầu nhận nội dung web (Commit) -> Inject Document Start Scripts & Storage
        public func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
            guard let url = webView.url else { return }

            // Đồng bộ dữ liệu storage từ UserDefaults vào localStorage trước khi script chạy
            let savedStorage = UserDefaults.standard.string(forKey: "sc_cue_storage") ?? "{}"
            let escaped = savedStorage.replacingOccurrences(of: "\\", with: "\\\\")
                                      .replacingOccurrences(of: "'", with: "\\'")
            let initStorageScript = "try { localStorage.setItem('sc_cue_storage', '\(escaped)'); } catch(e){}"
            webView.evaluateJavaScript(initStorageScript, completionHandler: nil)

            // Inject các script Document Start
            let startScripts = self.parent.extensionManager.getScriptsToInject(for: url, runAt: .documentStart)
            for script in startScripts {
                webView.evaluateJavaScript(script) { _, err in
                    if let err = err {
                        print("[BrowserWebView] Lỗi inject start script:", err.localizedDescription)
                    }
                }
            }

            // Inject CSS
            let cssList = self.parent.extensionManager.getCSSToInject(for: url)
            for css in cssList {
                let escapedCss = css.replacingOccurrences(of: "\\", with: "\\\\")
                                    .replacingOccurrences(of: "`", with: "\\`")
                let cssScript = """
                (() => {
                    const style = document.createElement('style');
                    style.textContent = `\(escapedCss)`;
                    (document.head || document.documentElement).appendChild(style);
                })();
                """
                webView.evaluateJavaScript(cssScript, completionHandler: nil)
            }
        }

        // 3. Khi tải trang xong (Finish) -> Inject Document End & Idle Scripts
        public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            DispatchQueue.main.async {
                self.parent.isLoading = false
                self.parent.canGoBack = webView.canGoBack
                self.parent.canGoForward = webView.canGoForward
                self.parent.webTitle = webView.title ?? ""
                if let url = webView.url {
                    self.parent.currentURLString = url.absoluteString
                }
            }

            guard let url = webView.url else { return }

            // Inject Document End
            let endScripts = self.parent.extensionManager.getScriptsToInject(for: url, runAt: .documentEnd)
            for script in endScripts {
                webView.evaluateJavaScript(script) { _, err in
                    if let err = err {
                        print("[BrowserWebView] Lỗi inject end script:", err.localizedDescription)
                    }
                }
            }

            // Inject Document Idle sau một khoảng ngắn
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                let idleScripts = self.parent.extensionManager.getScriptsToInject(for: url, runAt: .documentIdle)
                for script in idleScripts {
                    webView.evaluateJavaScript(script, completionHandler: nil)
                }
            }
        }

        public func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            DispatchQueue.main.async { self.parent.isLoading = false }
        }

        public func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            DispatchQueue.main.async { self.parent.isLoading = false }
        }

        // MARK: - WKUIDelegate (Xử lý Popup, Alert, Target _blank)
        public func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
            // Mở link target="_blank" ngay trong cùng webview
            if navigationAction.targetFrame == nil {
                webView.load(navigationAction.request)
            }
            return nil
        }

        public func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
            let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in completionHandler() })
            topViewController()?.present(alert, animated: true)
        }

        public func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (Bool) -> Void) {
            let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Hủy", style: .cancel) { _ in completionHandler(false) })
            alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in completionHandler(true) })
            topViewController()?.present(alert, animated: true)
        }

        public func webView(_ webView: WKWebView, runJavaScriptTextInputPanelWithPrompt prompt: String, defaultText: String?, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (String?) -> Void) {
            let alert = UIAlertController(title: nil, message: prompt, preferredStyle: .alert)
            alert.addTextField { tf in tf.text = defaultText }
            alert.addAction(UIAlertAction(title: "Hủy", style: .cancel) { _ in completionHandler(nil) })
            alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in completionHandler(alert.textFields?.first?.text) })
            topViewController()?.present(alert, animated: true)
        }

        private func topViewController() -> UIViewController? {
            let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
            return scenes.first?.windows.first(where: { $0.isKeyWindow })?.rootViewController
        }
    }
}
