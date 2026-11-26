//
//  CaptchaBridge.swift
//  PPSRControl
//
//  Created by Rork on September 11, 2026.
//

import Foundation
import WebKit

/// Receives messages posted by the all-frames captcha script.
///
/// The human-verification checkbox lives inside a cross-origin hCaptcha iframe, which the
/// page's own injected JavaScript cannot touch. A `WKUserScript` with
/// `forMainFrameOnly: false` runs inside that iframe too, and posts back here so the engine
/// learns the frame exists. The engine can then drive that exact frame with
/// `evaluateJavaScript(_:in:contentWorld:)`.
final class CaptchaBridge: NSObject, WKScriptMessageHandler {

    /// Message handler name the injected script posts to.
    static let messageName = "rorkCaptcha"

    private let onEvent: (String, WKFrameInfo) -> Void

    /// - Parameter onEvent: called with the reported state (`found`, `pressed`, `verified`)
    ///   and the frame that reported it. Capture the engine weakly — the web view's
    ///   content controller retains this handler.
    init(onEvent: @escaping (String, WKFrameInfo) -> Void) {
        self.onEvent = onEvent
        super.init()
    }

    func userContentController(_ userContentController: WKUserContentController,
                               didReceive message: WKScriptMessage) {
        guard let body = message.body as? String, !body.isEmpty else { return }
        onEvent(body, message.frameInfo)
    }
}
