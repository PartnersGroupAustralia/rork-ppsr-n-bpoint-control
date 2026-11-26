//
//  ResultsView.swift
//  PPSRControl
//
//  Created by Rork on August 3, 2026.
//

import SwiftUI

/// Results tab — list of all results with colored status badges, swipe-to-delete,
/// and a swipeable screenshot gallery accessible via a toolbar button.
/// Data updates live via the observable automation engine.
struct ResultsView: View {
    let engine: PpsrAutomationEngine

    @State private var viewModel: ResultsViewModel?
    @State private var showGallery = false

    var body: some View {
        NavigationStack {
            Group {
                if viewModel == nil {
                    LoadingState()
                } else if vm.results.isEmpty {
                    EmptyState(message: vm.errorMessage ?? "No results yet. Load cards and start the automation.")
                } else {
                    resultsList
                }
            }
            .navigationTitle("Results")
            .toolbar {
                if !vm.results.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            showGallery = true
                        } label: {
                            Image(systemName: "photo.on.rectangle.angled")
                        }
                        .accessibilityLabel("Screenshot Gallery")
                    }
                }
            }
            .alert("Error", isPresented: .constant(vm.errorMessage != nil)) {
                Button("OK") { vm.clearError() }
            } message: {
                Text(vm.errorMessage ?? "")
            }
            .fullScreenCover(isPresented: $showGallery) {
                ScreenshotGalleryView(results: vm.results, title: "All Screenshots")
            }
        }
        .onAppear {
            if viewModel == nil {
                viewModel = ResultsViewModel(engine: engine)
            }
        }
    }

    private var vm: ResultsViewModel {
        viewModel ?? ResultsViewModel(engine: engine)
    }

    private var resultsList: some View {
        List(vm.results) { result in
            NavigationLink(value: result) {
                ResultRow(result: result)
            }
            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                Button(role: .destructive) {
                    vm.deleteResult(result)
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationDestination(for: PpsrResult.self) { result in
            ResultDetailView(result: result)
        }
    }
}

// MARK: - Result Row

private struct ResultRow: View {
    let result: PpsrResult

    private var status: ResultStatus {
        ResultStatus.from(result.status)
    }

    var body: some View {
        HStack(spacing: 12) {
            StatusBadge(status: status)

            VStack(alignment: .leading, spacing: 4) {
                Text(result.maskedCard)
                    .font(.subheadline.monospacedDigit())
                    .fontWeight(.medium)
                Text(result.vin)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(result.timestamp)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Status Badge

struct StatusBadge: View {
    let status: ResultStatus

    var body: some View {
        VStack(spacing: 2) {
            Image(systemName: status.iconName)
                .font(.callout)
            Text(status.label)
                .font(.system(size: 8, weight: .medium))
        }
        .foregroundStyle(status.badgeColor)
        .frame(width: 52, height: 48)
        .background(status.badgeColor.opacity(0.12),
                    in: .rect(cornerRadius: 10))
    }
}

// MARK: - States

struct LoadingState: View {
    var body: some View {
        VStack(spacing: 12) {
            ProgressView()
                .scaleEffect(1.2)
            Text("Loading…")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct EmptyState: View {
    let message: String

    var body: some View {
        ContentUnavailableView {
            Label("No Data", systemImage: "tray")
        } description: {
            Text(message)
        }
    }
}

// MARK: - Screenshot Gallery

/// Full-screen swipeable gallery of all screenshots from a result set.
/// Navigate left/right through screenshots with pinch-to-zoom on each image.
struct ScreenshotGalleryView: View {
    let results: [PpsrResult]
    let title: String

    @Environment(\.dismiss) private var dismiss

    /// Only results that have a screenshot file.
    private var resultsWithScreenshots: [PpsrResult] {
        results.filter { $0.screenshotURL != nil }
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if resultsWithScreenshots.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.largeTitle)
                        .foregroundStyle(.white.opacity(0.4))
                    Text("No screenshots available")
                        .foregroundStyle(.white.opacity(0.5))
                }
            } else {
                TabView(selection: $currentIndex) {
                    ForEach(Array(resultsWithScreenshots.enumerated()), id: \.offset) { index, result in
                        GalleryPage(result: result, index: index, total: resultsWithScreenshots.count)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .ignoresSafeArea()
            }

            // Overlay header with close button and counter
            VStack {
                HStack {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(.white)
                    Spacer()
                    if !resultsWithScreenshots.isEmpty {
                        Text("\(currentIndex + 1) / \(resultsWithScreenshots.count)")
                            .font(.subheadline.monospacedDigit())
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }
                .padding()
                .background(.black.opacity(0.3))
                Spacer()
            }
        }
    }

    @State private var currentIndex: Int = 0
}

/// Single page in the screenshot gallery — pinch-to-zoom + double-tap.
private struct GalleryPage: View {
    let result: PpsrResult
    let index: Int
    let total: Int

    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0

    var body: some View {
        VStack(spacing: 12) {
            AsyncImage(url: result.screenshotURL) { phase in
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
                    VStack(spacing: 8) {
                        Image(systemName: "photo.badge.exclamationmark")
                            .font(.largeTitle)
                            .foregroundStyle(.white.opacity(0.4))
                        Text("Screenshot unavailable")
                            .foregroundStyle(.white.opacity(0.5))
                            .font(.caption)
                    }
                } else {
                    ProgressView()
                        .tint(.white)
                }
            }

            // Caption with masked card + VIN
            VStack(spacing: 4) {
                Text(result.maskedCard)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.white.opacity(0.8))
                Text(result.vin)
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.5))
            }
            .padding(.bottom, 20)
        }
    }
}

#Preview {
    ResultsView(engine: PpsrAutomationEngine())
        .environment(\.colorScheme, .dark)
}
