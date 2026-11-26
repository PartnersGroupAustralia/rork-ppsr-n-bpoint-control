//
//  ResultDetailView.swift
//  PPSRControl
//
//  Created by Rork on August 3, 2026.
//

import SwiftUI

/// Detail view for a single result — masked card, VIN, email, timestamp, full screenshot.
/// Screenshots are loaded from local files captured by the on-device engine.
struct ResultDetailView: View {
    let result: PpsrResult

    private var status: ResultStatus {
        ResultStatus.from(result.status)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                screenshotSection
                detailsSection
            }
        }
        .navigationTitle("Result Detail")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var screenshotSection: some View {
        Color(.secondarySystemBackground)
            .frame(height: 300)
            .overlay {
                AsyncImage(url: result.screenshotURL) { phase in
                    if let image = phase.image {
                        image.resizable().aspectRatio(contentMode: .fit)
                    } else if phase.error != nil {
                        ScreenshotErrorView()
                    } else {
                        ProgressView()
                    }
                }
                .allowsHitTesting(false)
            }
            .clipped()
    }

    private var detailsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            StatusBadge(status: status)
                .frame(maxWidth: .infinity, alignment: .leading)

            DetailRow(label: "Card", value: result.maskedCard, mono: true)
            DetailRow(label: "VIN", value: result.vin, mono: true)
            DetailRow(label: "Email", value: result.email)
            DetailRow(label: "Timestamp", value: result.timestamp)
            DetailRow(label: "Raw Status", value: result.status, mono: true)
        }
        .padding()
    }
}

// MARK: - Screenshot Error

private struct ScreenshotErrorView: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "photo.badge.exclamationmark")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("Screenshot unavailable")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Detail Row

struct DetailRow: View {
    let label: String
    let value: String
    var mono: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label.uppercased())
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
            Text(value)
                .font(mono ? .body.monospaced() : .body)
                .textSelection(.enabled)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    NavigationStack {
        ResultDetailView(
            result: PpsrResult(card: "4111****1111", vin: "1HGCM82633A123456",
                               email: "test@example.com", status: "RESULTS_FOUND",
                               screenshot: nil, timestamp: "2026-08-03T10:30")
        )
    }
    .environment(\.colorScheme, .dark)
}
