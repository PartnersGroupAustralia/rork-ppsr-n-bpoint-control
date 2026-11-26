//
//  SettingsView.swift
//  PPSRControl
//
//  Created by Rork on August 3, 2026.
//

import SwiftUI
import UniformTypeIdentifiers

/// Settings tab — receipt email, auto-refresh toggle, open PPSR in Safari, export successful cards.
/// No backend URL needed — automation runs on-device.
struct SettingsView: View {
    let settings: AppSettings
    let engine: PpsrAutomationEngine

    @State private var viewModel: SettingsViewModel?
    @State private var emailInput: String = ""
    @State private var showSafari = false
    @State private var exportFileURL: URL?

    var body: some View {
        NavigationStack {
            Form {
                accountSection
                autoGenerateSection
                bpointSection
                retrySection
                backgroundSection
                dashboardSection
                actionsSection
                aboutSection
            }
            .navigationTitle("Settings")
            .onAppear {
                emailInput = settings.email
                if viewModel == nil {
                    viewModel = SettingsViewModel(engine: engine)
                }
            }
            .alert("Error", isPresented: .constant(vm.errorMessage != nil)) {
                Button("OK") { vm.clearError() }
            } message: {
                Text(vm.errorMessage ?? "")
            }
            .sheet(isPresented: $showSafari) {
                SafariView(url: URL(string: "https://transact.ppsr.gov.au/CarCheck/")!)
            }
        }
    }

    private var vm: SettingsViewModel {
        viewModel ?? SettingsViewModel(engine: engine)
    }

    // MARK: - Account

    private var accountSection: some View {
        Section {
            TextField("you@example.com", text: $emailInput)
                .keyboardType(.emailAddress)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)

            Button {
                settings.email = emailInput.trimmingCharacters(in: .whitespacesAndNewlines)
            } label: {
                Label("Save Email", systemImage: "square.and.arrow.down")
            }
        } header: {
            Text("PPSR Account")
        } footer: {
            Text("Email address used for PPSR check receipts during automation.")
        }
    }

    // MARK: - Bpoint Payment

    private var bpointSection: some View {
        Section {
            Picker("Amount", selection: Binding(
                get: { settings.bpointAmount },
                set: { settings.bpointAmount = $0 }
            )) {
                ForEach(AppSettings.bpointAmounts, id: \.self) { amount in
                    Text("$\(amount)").tag(amount)
                }
            }
            .pickerStyle(.segmented)

            LabeledContent("Payment Page", value: "Our Lady of the Way")
        } header: {
            Text("Bpoint Payment")
        } footer: {
            Text("Amount filled into the Bpoint payment form when Bpoint mode is selected on the Dashboard. Cards starting with 4 are submitted as Visa, cards starting with 5 as Mastercard.")
        }
    }

    // MARK: - Auto-Retry

    private var retrySection: some View {
        Section {
            Toggle(isOn: Binding(
                get: { settings.autoRetryEnabled },
                set: { settings.autoRetryEnabled = $0 }
            )) {
                Label("Auto-Retry on Fail", systemImage: "arrow.clockwise.circle")
            }
            if settings.autoRetryEnabled {
                LabeledContent("Max Retries", value: "1 attempt")
            }
        } header: {
            Text("Retry")
        } footer: {
            Text("When enabled, cards that return PAYMENT_ERROR or UNKNOWN are automatically retried once before moving to the next card.")
        }
    }

    // MARK: - Background Processing

    private var backgroundSection: some View {
        Section {
            Toggle(isOn: Binding(
                get: { settings.backgroundProcessingEnabled },
                set: { settings.backgroundProcessingEnabled = $0 }
            )) {
                Label("Background Processing", systemImage: "moon.zzz")
            }
        } header: {
            Text("Background")
        } footer: {
            Text("When enabled, automation requests extra execution time to continue processing when the app moves to the background. iOS may still suspend the app after a limited period.")
        }
    }

    // MARK: - Dashboard

    private var dashboardSection: some View {
        Section {
            Toggle(isOn: Binding(
                get: { settings.autoRefreshDashboard },
                set: { settings.autoRefreshDashboard = $0 }
            )) {
                Label("Auto-refresh Dashboard", systemImage: "arrow.clockwise")
            }
        } header: {
            Text("Dashboard")
        } footer: {
            Text("With on-device automation, Dashboard data updates live as cards are processed. This setting is kept for future use.")
        }
    }

    // MARK: - Auto-Generate

    private var autoGenerateSection: some View {
        Section {
            Toggle(isOn: Binding(
                get: { settings.autoGenerateData },
                set: { settings.autoGenerateData = $0 }
            )) {
                Label("Auto-Generate VIN & Email", systemImage: "shuffle")
            }

            if settings.autoGenerateData {
                LabeledContent("VIN", value: "Random per card")
                LabeledContent("Email", value: engine.currentRunEmail ?? "Random per run")
            }
        } header: {
            Text("Data Generation")
        } footer: {
            Text("When enabled, each run auto-generates a random 17-character VIN for every card and a random email address for the entire run, instead of using the card list's VIN field or the saved email.")
        }
    }

    // MARK: - Actions

    private var actionsSection: some View {
        Section {
            Button {
                showSafari = true
            } label: {
                Label("Open PPSR in Safari", systemImage: "safari")
            }

            if vm.isExporting {
                HStack {
                    ProgressView()
                    Text("Exporting…")
                    Spacer()
                }
            } else if let exportFileURL {
                ShareLink(
                    item: exportFileURL,
                    preview: SharePreview("Successful Cards", image: Image(systemName: "checkmark.seal.fill"))
                ) {
                    Label("Export Successful Cards", systemImage: "square.and.arrow.up.on.square")
                }
                Button {
                    runExport()
                } label: {
                    Label("Re-download Export", systemImage: "arrow.clockwise")
                }
            } else {
                Button {
                    runExport()
                } label: {
                    Label("Export Successful Cards", systemImage: "square.and.arrow.up.on.square")
                }
            }
        } header: {
            Text("Actions")
        } footer: {
            if exportFileURL != nil {
                Text("Tap “Export Successful Cards” to open the share sheet.")
            } else {
                Text("Exports the full card details of all RESULTS_FOUND entries to a text file.")
            }
        }
    }

    // MARK: - About

    private var aboutSection: some View {
        Section {
            LabeledContent("Version", value: "2.0")
            LabeledContent("Engine", value: "On-device WKWebView")
            LabeledContent("Cards Loaded", value: "\(engine.cards.count)")
        } header: {
            Text("About")
        }
    }

    // MARK: - Export

    private func runExport() {
        vm.exportSuccessful()
        if let data = vm.exportedData, !data.isEmpty {
            exportFileURL = writeExportToFile(data)
        }
    }

    private func writeExportToFile(_ data: Data) -> URL? {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("ppsr_successful_cards.txt")
        do {
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }
}

#Preview {
    SettingsView(settings: AppSettings(), engine: PpsrAutomationEngine())
        .environment(\.colorScheme, .dark)
}
