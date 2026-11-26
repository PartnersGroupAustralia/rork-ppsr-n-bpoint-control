//
//  SuccessfulView.swift
//  PPSRControl
//
//  Created by Rork on August 3, 2026.
//

import SwiftUI
import UIKit
import UniformTypeIdentifiers

/// Successful tab — gallery grid of RESULTS_FOUND results with full-screen screenshot viewer,
/// swipe-to-delete, screenshot gallery, and export of successful results.
/// Screenshots are loaded from local files captured by the on-device engine.
struct SuccessfulView: View {
    let engine: PpsrAutomationEngine

    @State private var viewModel: ResultsViewModel?
    @State private var selectedScreenshot: URL?
    @State private var showGallery = false
    @State private var showExportSheet = false
    @State private var exportFileURL: URL?
    @State private var showCopiedToast = false
    @State private var copiedCount = 0

    private let columns = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8),
    ]

    var body: some View {
        NavigationStack {
            Group {
                if viewModel == nil {
                    LoadingState()
                } else if vm.successfulResults.isEmpty {
                    EmptyState(message: "No successful results yet.")
                } else {
                    galleryGrid
                }
            }
            .navigationTitle("Successful")
            .toolbar {
                if !vm.successfulResults.isEmpty {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            showGallery = true
                        } label: {
                            Image(systemName: "photo.on.rectangle.angled")
                        }
                        .accessibilityLabel("Screenshot Gallery")
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Menu {
                            Button {
                                copyToClipboard()
                            } label: {
                                Label("Copy as .txt", systemImage: "doc.on.clipboard")
                            }

                            if let exportFileURL {
                                ShareLink(
                                    item: exportFileURL,
                                    preview: SharePreview(
                                        "Successful Results",
                                        image: Image(systemName: "checkmark.seal.fill"))
                                ) {
                                    Label("Share .txt File", systemImage: "square.and.arrow.up")
                                }
                            }
                        } label: {
                            Image(systemName: "square.and.arrow.up")
                        }
                        .accessibilityLabel("Export Successful Results")
                    }
                }
            }
            .alert("Error", isPresented: .constant(vm.errorMessage != nil)) {
                Button("OK") { vm.clearError() }
            } message: {
                Text(vm.errorMessage ?? "")
            }
            .fullScreenCover(item: Binding(
                get: { selectedScreenshot.map { ScreenshotURL(url: $0) } },
                set: { selectedScreenshot = $0?.url }
            )) { wrapper in
                FullscreenScreenshotView(url: wrapper.url)
            }
            .fullScreenCover(isPresented: $showGallery) {
                ScreenshotGalleryView(results: vm.successfulResults, title: "Successful Screenshots")
            }
            .overlay(alignment: .bottom) {
                if showCopiedToast {
                    CopiedToast(count: copiedCount)
                        .padding(.bottom, 24)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .onAppear {
            if viewModel == nil {
                viewModel = ResultsViewModel(engine: engine)
            }
            // Prepare the share file up front so the menu's share action works on first tap.
            exportSuccessful()
        }
        .onChange(of: vm.successfulResults.count) { _, _ in
            exportSuccessful()
        }
    }

    private var vm: ResultsViewModel {
        viewModel ?? ResultsViewModel(engine: engine)
    }

    private var galleryGrid: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(vm.successfulResults) { result in
                    GalleryCell(result: result) {
                        selectedScreenshot = result.screenshotURL
                    }
                    .contextMenu {
                        Button(role: .destructive) {
                            vm.deleteResult(result)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 24)
        }
    }

    // MARK: - Export

    /// Exports successful results to a temp file for the share sheet.
    private func exportSuccessful() {
        let data = engine.exportSuccessful()
        guard !data.isEmpty else {
            exportFileURL = nil
            return
        }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("ppsr_successful_results.txt")
        do {
            try data.write(to: url, options: .atomic)
            exportFileURL = url
        } catch {
            exportFileURL = nil
        }
    }

    /// Copies the successful cards to the system clipboard as plain text,
    /// one `card mm/yy cvv vin` entry per line.
    private func copyToClipboard() {
        let text = engine.exportSuccessfulText()
        guard !text.isEmpty else { return }

        UIPasteboard.general.string = text
        copiedCount = text.split(separator: "\n").count
        UINotificationFeedbackGenerator().notificationOccurred(.success)

        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
            showCopiedToast = true
        }
        Task {
            try? await Task.sleep(for: .seconds(1.8))
            withAnimation(.easeOut(duration: 0.25)) {
                showCopiedToast = false
            }
        }
    }
}

// MARK: - Copied Toast

/// Transient confirmation shown after copying cards to the clipboard.
private struct CopiedToast: View {
    let count: Int

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "doc.on.clipboard.fill")
                .font(.footnote.weight(.semibold))
            Text(count == 1 ? "1 card copied" : "\(count) cards copied")
                .font(.footnote.weight(.semibold))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.green.gradient, in: .capsule)
        .shadow(color: .black.opacity(0.25), radius: 8, y: 4)
    }
}

// MARK: - Gallery Cell

private struct GalleryCell: View {
    let result: PpsrResult
    let onTap: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Color(.secondarySystemBackground)
                .frame(height: 140)
                .overlay {
                    AsyncImage(url: result.screenshotURL) { phase in
                        if let image = phase.image {
                            image.resizable().aspectRatio(contentMode: .fill)
                        } else {
                            Image(systemName: "photo")
                                .foregroundStyle(.secondary)
                                .font(.title2)
                        }
                    }
                    .allowsHitTesting(false)
                }
                .clipShape(.rect(cornerRadius: 10), style: FillStyle())

            VStack(alignment: .leading, spacing: 2) {
                Text(result.maskedCard)
                    .font(.caption.monospacedDigit())
                    .lineLimit(1)
                Text(result.vin)
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Text(result.timestamp)
                    .font(.system(size: 8))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(6)
        }
        .background(Color(.tertiarySystemBackground),
                    in: .rect(cornerRadius: 10))
        .onTapGesture(perform: onTap)
    }
}

// MARK: - Fullscreen Screenshot (single image)

private struct FullscreenScreenshotView: View {
    let url: URL?

    @Environment(\.dismiss) private var dismiss
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            AsyncImage(url: url) { phase in
                if let image = phase.image {
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .scaleEffect(scale)
                        .gesture(
                            MagnifyGesture()
                                .onChanged { value in
                                    scale = lastScale * value.magnification
                                }
                                .onEnded { _ in
                                    lastScale = scale
                                    if scale < 1 { scale = 1; lastScale = 1 }
                                }
                        )
                        .onTapGesture(count: 2) {
                            scale = scale > 1 ? 1 : 2
                            lastScale = scale
                        }
                } else if phase.error != nil {
                    VStack(spacing: 12) {
                        Image(systemName: "photo.badge.exclamationmark")
                            .font(.largeTitle)
                            .foregroundStyle(.white.opacity(0.5))
                        Text("Could not load screenshot")
                            .foregroundStyle(.white.opacity(0.5))
                    }
                } else {
                    ProgressView()
                        .tint(.white)
                }
            }

            VStack {
                HStack {
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }
                Spacer()
            }
            .padding()
        }
    }
}

// MARK: - URL Wrapper for fullScreenCover

private struct ScreenshotURL: Identifiable {
    let url: URL
    var id: String { url.absoluteString }
}

#Preview {
    SuccessfulView(engine: PpsrAutomationEngine())
        .environment(\.colorScheme, .dark)
}
