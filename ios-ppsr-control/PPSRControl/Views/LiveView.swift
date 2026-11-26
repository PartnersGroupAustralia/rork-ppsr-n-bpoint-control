//
//  LiveWebView.swift
//  PPSRControl
//
//  Created by Rork on August 3, 2026.
//

import SwiftUI
import WebKit

/// SwiftUI wrapper that displays the engine's live WKWebView so the user can
/// watch automation happen in real time.
struct LiveWebView: UIViewRepresentable {
    let webView: WKWebView

    func makeUIView(context: Context) -> WKWebView {
        // The webView is already configured by the engine — just return it.
        // Ensure it's scrollable and not zoomed.
        webView.scrollView.minimumZoomScale = 1.0
        webView.scrollView.maximumZoomScale = 1.0
        webView.scrollView.isScrollEnabled = true
        webView.allowsBackForwardNavigationGestures = false
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        // No-op — the engine drives the content.
    }
}

/// Live tab — shows the actual WKWebView running the PPSR automation in real time,
/// plus a debug log of what the JS injection is doing.
/// The PPSR site has its own loading animation after clicking "Show my results",
/// so no custom overlay is shown here.
struct LiveView: View {
    let engine: PpsrAutomationEngine

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Status bar
                HStack(spacing: 8) {
                    Circle()
                        .fill(engine.isRunning ? .green : .secondary)
                        .frame(width: 8, height: 8)
                    Text(engine.isRunning ? "Running" : "Idle")
                        .font(.caption.weight(.medium))
                    Spacer()
                    if engine.progress.totalCards > 0 {
                        Text("\(engine.progress.currentIndex) / \(engine.progress.totalCards)")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Color(.secondarySystemBackground))

                // Human-verification prompt — shown while Bpoint automation waits for
                // the user to tick the "I am human" box (it sits in a cross-origin frame).
                if engine.needsCaptchaTap {
                    HStack(spacing: 8) {
                        Image(systemName: "hand.tap.fill")
                            .font(.footnote)
                        Text("Tap the \"I am human\" box above")
                            .font(.footnote.weight(.semibold))
                        Spacer()
                    }
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color(.tertiarySystemBackground))
                    .transition(.move(edge: .top).combined(with: .opacity))
                }

                // Live WebView — no custom overlay, so PPSR's own spinner is visible
                LiveWebView(webView: engine.webView)
                    .frame(maxWidth: .infinity)
                    .frame(maxHeight: .infinity)
                    .background(Color.black)

                // Debug log
                DebugLogView(engine: engine)
                    .frame(height: 140)
                    .background(Color(.tertiarySystemBackground))
            }
            .navigationTitle("Live")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - Debug Log View

private struct DebugLogView: View {
    let engine: PpsrAutomationEngine

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Debug Log")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                Spacer()
                Image(systemName: "ladybug")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.top, 6)
            .padding(.bottom, 4)

            ScrollView {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(engine.debugLog.suffix(50), id: \.self) { entry in
                        Text(entry)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(logColor(entry))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 8)
            }
        }
    }

    private func logColor(_ entry: String) -> Color {
        if entry.contains("[FAIL]") || entry.contains("[ERROR]") { return .red }
        if entry.contains("[OK]") { return .green }
        if entry.contains("[STEP]") { return .accentColor }
        if entry.contains("[RETRY]") || entry.contains("[HUMAN]") { return .orange }
        if entry.contains("[PROCEED]") || entry.contains("[CARDTYPE]") { return .accentColor }
        if entry.contains("[WAIT]") { return .cyan }
        return .secondary
    }
}

#Preview {
    LiveView(engine: PpsrAutomationEngine())
        .environment(\.colorScheme, .dark)
}
