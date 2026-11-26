//
//  CardsView.swift
//  PPSRControl
//
//  Created by Rork on August 3, 2026.
//

import SwiftUI

/// Cards tab — multi-line editor for pasting many cards at once.
/// Cards are saved to an in-memory queue in the engine, waiting to be tested from the Dashboard.
struct CardsView: View {
    let engine: PpsrAutomationEngine

    @State private var viewModel: CardsViewModel?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    editorSection
                    saveSection
                    queueSection
                }
                .padding()
            }
            .navigationTitle("Cards")
            .alert("Error", isPresented: .constant(vm.errorMessage != nil)) {
                Button("OK") { vm.clearError() }
            } message: {
                Text(vm.errorMessage ?? "")
            }
        }
        .onAppear {
            if viewModel == nil {
                viewModel = CardsViewModel(engine: engine)
            }
        }
    }

    private var vm: CardsViewModel {
        viewModel ?? CardsViewModel(engine: engine)
    }

    // MARK: - Editor

    private var editorSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Paste Card List")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            TextEditor(text: Binding(
                get: { vm.rawText },
                set: { vm.rawText = $0 }
            ))
                .frame(minHeight: 180)
                .font(.system(.body, design: .monospaced))
                .padding(8)
                .background(Color(.secondarySystemBackground),
                            in: .rect(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color(.separator), lineWidth: 0.5)
                )
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)

            HStack(spacing: 12) {
                CountChip(label: "Valid", count: vm.validCount, color: .green)
                CountChip(label: "Skipped", count: vm.skippedCount, color: .orange)
            }

            Text("Supported formats — one per line:")
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 3) {
                Text("• card mm/yy cvv")
                Text("• card mm/yy cvv vin")
                Text("• card|mm|yy|cvv")
                Text("• card|mm|yy|cvv|vin")
                Text("• card mm yy cvv")
                Text("• card mm yy cvv vin")
            }
            .font(.system(size: 10, design: .monospaced))
            .foregroundStyle(.secondary)
            .padding(.leading, 4)
        }
    }

    // MARK: - Save / Clear

    private var saveSection: some View {
        VStack(spacing: 12) {
            Button {
                vm.saveToQueue()
            } label: {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("Save to Queue")
                        .fontWeight(.medium)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!vm.hasContent)

            HStack(spacing: 12) {
                Button {
                    vm.clearEditor()
                } label: {
                    Label("Clear Editor", systemImage: "xmark")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(!vm.hasContent)

                Button(role: .destructive) {
                    vm.clearQueue()
                } label: {
                    Label("Clear Queue", systemImage: "trash")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(!vm.hasQueuedCards)
            }

            if let saveResult = vm.saveResult {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                    Text(saveResult)
                        .font(.subheadline)
                    Spacer()
                }
                .foregroundStyle(.green)
                .padding(12)
                .background(Color.green.opacity(0.1),
                            in: .rect(cornerRadius: 10))
            }
        }
    }

    // MARK: - Queue (Waiting to be Tested)

    private var queueSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Waiting to be Tested")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)

                Spacer()

                Text("\(vm.queuedCards.count)")
                    .font(.caption.bold().monospacedDigit())
                    .foregroundStyle(.accent)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.accentColor.opacity(0.12),
                                in: Capsule())
            }

            if vm.queuedCards.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "creditcard.stack")
                        .font(.title2)
                        .foregroundStyle(.secondary.opacity(0.6))
                    Text("No cards queued yet")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("Paste a list of cards above and tap Save to Queue.")
                        .font(.caption)
                        .foregroundStyle(.secondary.opacity(0.7))
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
                .background(Color(.secondarySystemBackground),
                            in: .rect(cornerRadius: 14))
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(Array(vm.queuedCards.enumerated()), id: \.element.id) { index, card in
                        CardRow(card: card, index: index + 1)
                            .contextMenu {
                                Button(role: .destructive) {
                                    vm.removeCard(at: index)
                                } label: {
                                    Label("Remove", systemImage: "trash")
                                }
                            }
                    }
                }
                .padding(12)
                .background(Color(.secondarySystemBackground),
                            in: .rect(cornerRadius: 14))
            }
        }
    }
}

// MARK: - Card Row

private struct CardRow: View {
    let card: CardEntry
    let index: Int

    var body: some View {
        HStack(spacing: 12) {
            Text("\(index)")
                .font(.caption2.bold().monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(minWidth: 24, alignment: .leading)

            VStack(alignment: .leading, spacing: 4) {
                Text(CardFormatter.mask(card.card))
                    .font(.system(.subheadline, design: .monospaced))
                    .foregroundStyle(.primary)

                HStack(spacing: 12) {
                    Label("\(card.mm)/\(card.yy)", systemImage: "calendar")
                        .font(.caption)
                    Label(card.cvv, systemImage: "lock")
                        .font(.caption)
                }
                .foregroundStyle(.secondary)

                if !card.vin.isEmpty {
                    Label(card.vin, systemImage: "car")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()
        }
        .padding(.vertical, 6)
    }
}

// MARK: - Count Chip

private struct CountChip: View {
    let label: String
    let count: Int
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text("\(count)")
                .font(.title2.bold().monospacedDigit())
                .foregroundStyle(color)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(Color(.secondarySystemBackground),
                    in: .rect(cornerRadius: 10))
    }
}

#Preview {
    CardsView(engine: PpsrAutomationEngine())
        .environment(\.colorScheme, .dark)
}
