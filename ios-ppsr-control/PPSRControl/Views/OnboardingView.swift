//
//  OnboardingView.swift
//  PPSRControl
//
//  Created by Rork on August 3, 2026.
//

import SwiftUI

/// First-launch onboarding screen that collects the PPSR account email.
/// This email is used for receipt delivery during automated checks.
struct OnboardingView: View {
    let settings: AppSettings

    @State private var emailInput: String = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    headerSection
                    emailFieldSection
                    Spacer(minLength: 20)
                    saveButton
                }
                .padding(.horizontal, 24)
                .padding(.top, 12)
            }
            .navigationTitle("PPSR Control")
            .navigationBarTitleDisplayMode(.inline)
            .background(Color(.systemBackground))
        }
        .onAppear {
            emailInput = settings.email
        }
    }

    private var headerSection: some View {
        VStack(spacing: 16) {
            Image(systemName: "car.2.fill")
                .font(.system(size: 64, weight: .light))
                .foregroundStyle(Color.accentColor)
                .padding(.top, 20)

            Text("Welcome to PPSR Control")
                .font(.title2.bold())

            Text("This app runs PPSR vehicle encumbrance checks directly on your iPhone — no Mac or backend server needed. Enter the email address to use for PPSR check receipts.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var emailFieldSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Receipt Email")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            TextField("you@example.com", text: $emailInput)
                .textFieldStyle(.roundedBorder)
                .keyboardType(.emailAddress)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .focused($isFocused)
        }
    }

    private var saveButton: some View {
        Button {
            saveAndContinue()
        } label: {
            Text("Save & Continue")
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .disabled(emailInput.trimmingCharacters(in: .whitespaces).isEmpty)
    }

    private func saveAndContinue() {
        settings.email = emailInput.trimmingCharacters(in: .whitespacesAndNewlines)
        settings.hasCompletedOnboarding = true
    }
}

#Preview {
    OnboardingView(settings: AppSettings())
        .environment(\.colorScheme, .dark)
}
