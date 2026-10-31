//
//  ExtensionManagerView.swift
//  ExtensionBrowser
//
//  Giao diện Quản lý Extension: Cài đặt từ ZIP, Bật/Tắt, Mở Popup, Xóa
//

import SwiftUI
import UniformTypeIdentifiers

public struct ExtensionManagerView: View {
    @ObservedObject public var manager = WebExtensionManager.shared
    @Environment(\.presentationMode) var presentationMode
    @State private var showingFilePicker = false
    @State private var selectedExtensionForPopup: WebExtension? = nil

    public var body: some View {
        NavigationView {
            List {
                // Section Cài đặt mới
                Section {
                    Button(action: { showingFilePicker = true }) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(.orange)
                                .font(.title3)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Cài Extension từ file ZIP")
                                    .fontWeight(.semibold)
                                    .foregroundColor(.primary)
                                Text("Chọn tệp .zip của Chrome Extension từ máy")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }

                // Banner thông báo nếu có
                if let status = manager.statusMessage {
                    Section {
                        Text(status)
                            .font(.subheadline)
                            .foregroundColor(.orange)
                            .padding(.vertical, 4)
                    }
                }

                // Section Danh sách Extension đã cài
                Section(header: Text("EXTENSION ĐÃ CÀI ĐẶT (\(manager.extensions.count))")) {
                    if manager.extensions.isEmpty {
                        Text("Chưa có Extension nào. Bấm vào nút bên trên để cài đặt từ file ZIP.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .padding(.vertical, 8)
                    } else {
                        ForEach(manager.extensions) { ext in
                            ExtensionRowView(
                                ext: ext,
                                onOpenPopup: { selectedExtensionForPopup = ext },
                                onDelete: { manager.deleteExtension(ext) }
                            )
                        }
                    }
                }
            }
            .listStyle(InsetGroupedListStyle())
            .navigationBarTitle("Quản lý Extension", displayMode: .inline)
            .navigationBarItems(trailing: Button("Xong") {
                presentationMode.wrappedValue.dismiss()
            })
            .sheet(isPresented: $showingFilePicker) {
                DocumentPickerView { url in
                    manager.installExtension(fromZipURL: url)
                }
            }
            .sheet(item: $selectedExtensionForPopup) { ext in
                ExtensionPopupView(extension: ext)
            }
        }
    }
}

// MARK: - Row hiển thị từng Extension
public struct ExtensionRowView: View {
    @ObservedObject public var ext: WebExtension
    public var onOpenPopup: () -> Void
    public var onDelete: () -> Void

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                if let img = ext.iconImage {
                    Image(uiImage: img)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 38, height: 38)
                        .cornerRadius(8)
                } else {
                    Image(systemName: "puzzlepiece.extension.fill")
                        .foregroundColor(.orange)
                        .font(.title2)
                        .frame(width: 38, height: 38)
                }

                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(ext.name)
                            .font(.headline)
                            .lineLimit(1)
                        Text("v\(ext.version)")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.orange.opacity(0.15))
                            .foregroundColor(.orange)
                            .cornerRadius(4)
                    }

                    if !ext.description.isEmpty {
                        Text(ext.description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                }

                Spacer()

                Toggle("", isOn: $ext.isEnabled)
                    .labelsHidden()
            }

            // Thanh thao tác nhanh cho extension
            HStack(spacing: 12) {
                if ext.popupURL != nil {
                    Button(action: onOpenPopup) {
                        Label("Mở Popup", systemImage: "macwindow.on.rectangle")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                    .buttonStyle(.borderless)
                }

                Spacer()

                Button(role: .destructive, action: onDelete) {
                    Label("Gỡ bỏ", systemImage: "trash")
                        .font(.caption)
                        .foregroundColor(.red)
                }
                .buttonStyle(.borderless)
            }
            .padding(.top, 2)
        }
        .padding(.vertical, 6)
    }
}

// MARK: - File Document Picker
public struct DocumentPickerView: UIViewControllerRepresentable {
    public var onPick: (URL) -> Void

    public func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.zip, .data], asCopy: true)
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
        return picker
    }

    public func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    public func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    public class Coordinator: NSObject, UIDocumentPickerDelegate {
        var parent: DocumentPickerView

        init(_ parent: DocumentPickerView) {
            self.parent = parent
        }

        public func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            _ = url.startAccessingSecurityScopedResource()
            parent.onPick(url)
            url.stopAccessingSecurityScopedResource()
        }
    }
}
