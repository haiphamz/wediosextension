//
//  ContentView.swift
//  ExtensionBrowser
//
//  Giao diện chính của Trình duyệt Web hỗ trợ Extension
//

import SwiftUI

public struct ContentView: View {
    @StateObject private var extensionManager = WebExtensionManager.shared

    @State private var currentURLString = "https://soundcloud.com/discover"
    @State private var inputURLText = "https://soundcloud.com/discover"
    @State private var webTitle = "SoundCloud"
    @State private var canGoBack = false
    @State private var canGoForward = false
    @State private var isLoading = false
    @State private var progress: Double = 0.0
    @State private var isDesktopMode = true

    @State private var triggerReload = false
    @State private var triggerBack = false
    @State private var triggerForward = false
    @State private var loadURLRequest: URLRequest? = nil

    // Sheets
    @State private var showingExtensionManager = false
    @State private var selectedExtensionForPopup: WebExtension? = nil

    public var body: some View {
        VStack(spacing: 0) {
            // MARK: - Top Header & Address Bar
            VStack(spacing: 6) {
                HStack(spacing: 8) {
                    // Nút Back
                    Button(action: { triggerBack.toggle() }) {
                        Image(systemName: "chevron.backward")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(canGoBack ? .primary : .gray.opacity(0.4))
                    }
                    .disabled(!canGoBack)

                    // Nút Forward
                    Button(action: { triggerForward.toggle() }) {
                        Image(systemName: "chevron.forward")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(canGoForward ? .primary : .gray.opacity(0.4))
                    }
                    .disabled(!canGoForward)

                    // Khung nhập URL & Tìm kiếm
                    HStack(spacing: 6) {
                        Image(systemName: inputURLText.hasPrefix("https") ? "lock.fill" : "globe")
                            .font(.system(size: 11))
                            .foregroundColor(inputURLText.hasPrefix("https") ? .green : .secondary)

                        TextField("Nhập địa chỉ web hoặc tìm kiếm...", text: $inputURLText, onCommit: navigateToInput)
                            .font(.system(size: 14))
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                            .keyboardType(.URL)

                        if !inputURLText.isEmpty {
                            Button(action: { inputURLText = "" }) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 13))
                                    .foregroundColor(.gray)
                            }
                        }

                        if isLoading {
                            ProgressView()
                                .scaleEffect(0.7)
                        } else {
                            Button(action: { triggerReload.toggle() }) {
                                Image(systemName: "arrow.clockwise")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.primary)
                            }
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(Color(UIColor.systemGray6))
                    .cornerRadius(10)

                    // Nút Toggle Desktop / Mobile Mode
                    Button(action: { isDesktopMode.toggle() }) {
                        Image(systemName: isDesktopMode ? "desktopcomputer" : "iphone")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(isDesktopMode ? .orange : .secondary)
                    }
                    .help(isDesktopMode ? "Chế độ Desktop (Bật)" : "Chế độ Mobile")

                    // Extension Quick Action (Nút Popup của Extension đang hoạt động, như SoundCloud Crossfader)
                    if let primaryExt = extensionManager.getActivePopupExtensions(for: URL(string: currentURLString)).first {
                        Button(action: { selectedExtensionForPopup = primaryExt }) {
                            if let icon = primaryExt.iconImage {
                                Image(uiImage: icon)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 22, height: 22)
                                    .cornerRadius(5)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 5)
                                            .stroke(Color.orange, lineWidth: 1.5)
                                    )
                            } else {
                                Image(systemName: "slider.horizontal.3")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(.orange)
                            }
                        }
                    }

                    // Nút Quản lý Extension (Icon mảnh ghép puzzle)
                    Button(action: { showingExtensionManager = true }) {
                        ZStack(alignment: .topTrailing) {
                            Image(systemName: "puzzlepiece.extension.fill")
                                .font(.system(size: 17))
                                .foregroundColor(.orange)

                            // Badge số lượng extension đang bật
                            let activeCount = extensionManager.extensions.filter { $0.isEnabled }.count
                            if activeCount > 0 {
                                Text("\(activeCount)")
                                    .font(.system(size: 9, weight: .black))
                                    .foregroundColor(.white)
                                    .padding(3)
                                    .background(Color.orange)
                                    .clipShape(Circle())
                                    .offset(x: 6, y: -6)
                            }
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.top, 6)
                .padding(.bottom, 4)

                // Thanh tiến trình tải trang (Progress bar)
                if isLoading && progress < 1.0 {
                    GeometryReader { geo in
                        Rectangle()
                            .fill(LinearGradient(gradient: Gradient(colors: [.orange, .red]), startPoint: .leading, endPoint: .trailing))
                            .frame(width: geo.size.width * CGFloat(progress), height: 2.5)
                    }
                    .frame(height: 2.5)
                } else {
                    Divider()
                }
            }
            .background(Color(UIColor.systemBackground))

            // MARK: - Main Web View
            BrowserWebView(
                extensionManager: extensionManager,
                currentURLString: $currentURLString,
                webTitle: $webTitle,
                canGoBack: $canGoBack,
                canGoForward: $canGoForward,
                isLoading: $isLoading,
                progress: $progress,
                isDesktopMode: $isDesktopMode,
                loadURLRequest: loadURLRequest,
                triggerReload: triggerReload,
                triggerBack: triggerBack,
                triggerForward: triggerForward
            )
            .onChange(of: currentURLString) { newURL in
                inputURLText = newURL
            }
        }
        .sheet(isPresented: $showingExtensionManager) {
            ExtensionManagerView(manager: extensionManager)
        }
        .sheet(item: $selectedExtensionForPopup) { ext in
            ExtensionPopupView(extension: ext)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("OpenExtensionPopupNotification"))) { notif in
            if let extId = notif.object as? String,
               let targetExt = extensionManager.extensions.first(where: { $0.id == extId }) {
                selectedExtensionForPopup = targetExt
            }
        }
    }

    private func navigateToInput() {
        var trimmed = inputURLText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        if !trimmed.hasPrefix("http://") && !trimmed.hasPrefix("https://") {
            if trimmed.contains(".") && !trimmed.contains(" ") {
                trimmed = "https://" + trimmed
            } else {
                // Tìm kiếm trên Google
                let query = trimmed.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? trimmed
                trimmed = "https://www.google.com/search?q=\(query)"
            }
        }

        if let validURL = URL(string: trimmed) {
            loadURLRequest = URLRequest(url: validURL)
        }
    }
}
