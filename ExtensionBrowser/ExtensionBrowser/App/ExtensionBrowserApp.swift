//
//  ExtensionBrowserApp.swift
//  ExtensionBrowser
//
//  Khởi tạo ứng dụng Trình duyệt iOS hỗ trợ Chrome Extension
//

import SwiftUI
import AVFoundation

@main
struct ExtensionBrowserApp: App {
    init() {
        configureAudioSession()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }

    private func configureAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers, .allowAirPlay])
            try session.setActive(true)
            print("[ExtensionBrowserApp] AudioSession cấu hình thành công: chế độ playback nền.")
        } catch {
            print("[ExtensionBrowserApp] Lỗi khởi tạo AudioSession:", error)
        }
    }
}
