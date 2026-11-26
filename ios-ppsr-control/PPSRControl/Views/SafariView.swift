//
//  SafariView.swift
//  PPSRControl
//
//  Created by Rork on August 3, 2026.
//

import SwiftUI
import SafariServices

/// UIKit representable that opens an in-app Safari sheet.
struct SafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        let config = SFSafariViewController.Configuration()
        config.entersReaderIfAvailable = false
        let controller = SFSafariViewController(url: url, configuration: config)
        controller.preferredControlTintColor = .systemCyan
        return controller
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}
