//
//  BpointScript.swift
//  PPSRControl
//
//  Created by Rork on September 2, 2026.
//

import Foundation

/// JavaScript used to drive the Bpoint payment form
/// (https://www.bpoint.com.au/payments/ourladyoftheway).
///
/// Flow, mapped from the page's own `payment.js`:
/// 1. Payer page — `#CRN1` (full name), `#CRN2` (phone/email), `#Amount`, then clicking the
///    card-logo `DIV` (`data-type="visa" | "mastercard"`) triggers `SubmitForm(dataType)`,
///    an AJAX POST that responds with a redirect to the card-entry page.
/// 2. Card page — card number, MM/YY boxes, CVN, a human-verification widget
///    (hCaptcha — its checkbox lives in a cross-origin frame injected JS cannot reach),
///    and a Proceed button.
enum BpointScript {

    /// Escapes a Swift string for safe interpolation into a JS single-quoted literal.
    private static func js(_ value: String) -> String {
        value.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "'", with: "\\'")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: " ")
    }

    // MARK: - Shared helpers (embedded in each script)

    /// JS preamble: a React/Vue-safe value setter plus event dispatch, matching the approach
    /// proven on the PPSR flow. Assigns via the prototype's own `value` descriptor so
    /// framework-tracked inputs register the change, then fires input/change/blur.
    private static let helpers = """
        function setVal(el, val) {
            var proto = el.tagName === 'TEXTAREA' ? HTMLTextAreaElement.prototype
                                                  : HTMLInputElement.prototype;
            var d = Object.getOwnPropertyDescriptor(proto, 'value');
            if (d && d.set) { d.set.call(el, val); } else { el.value = val; }
            el.dispatchEvent(new Event('input', {bubbles: true}));
            el.dispatchEvent(new Event('change', {bubbles: true}));
            el.dispatchEvent(new Event('blur', {bubbles: true}));
        }
        function visible(el) {
            if (!el || el.type === 'hidden') { return false; }
            var r = el.getBoundingClientRect();
            return r.width > 0 || r.height > 0;
        }
        function attrs(el) {
            return ((el.id || '') + ' ' + (el.name || '') + ' ' +
                    (el.getAttribute('aria-label') || '') + ' ' +
                    (el.placeholder || '') + ' ' +
                    (el.getAttribute('autocomplete') || '')).toLowerCase();
        }
        function press(el) {
            el.scrollIntoView({behavior: 'instant', block: 'center'});
            var r = el.getBoundingClientRect();
            var cx = r.left + r.width / 2, cy = r.top + r.height / 2;
            var opts = {bubbles: true, cancelable: true, view: window,
                        clientX: cx, clientY: cy, button: 0};
            try { el.focus(); } catch (e) {}
            try {
                var touch = new Touch({identifier: Date.now(), target: el,
                                       clientX: cx, clientY: cy});
                el.dispatchEvent(new TouchEvent('touchstart', {
                    bubbles: true, cancelable: true,
                    touches: [touch], targetTouches: [touch], changedTouches: [touch]}));
                el.dispatchEvent(new TouchEvent('touchend', {
                    bubbles: true, cancelable: true,
                    touches: [], targetTouches: [], changedTouches: [touch]}));
            } catch (e) {}
            try { el.dispatchEvent(new PointerEvent('pointerdown', opts)); } catch (e) {}
            try { el.dispatchEvent(new MouseEvent('mousedown', opts)); } catch (e) {}
            try { el.dispatchEvent(new PointerEvent('pointerup', opts)); } catch (e) {}
            try { el.dispatchEvent(new MouseEvent('mouseup', opts)); } catch (e) {}
            try { el.dispatchEvent(new MouseEvent('click', opts)); } catch (e) {}
            try { el.click(); } catch (e) {}
        }
    """

    // MARK: - Payer page

    /// Fills the payer details: full name, phone/email contact, and amount.
    /// All values are generated in Swift (no user-typed script content) and escaped anyway.
    /// - Returns: JS producing `ok name=… contact=… amount=…` or `missing=CRN1,…`.
    static func fillPayerDetails(name: String, contact: String, amount: String) -> String {
        """
        (function() {
            \(helpers)
            var missing = [];
            var nameEl = document.getElementById('CRN1');
            var contactEl = document.getElementById('CRN2');
            var amountEl = document.getElementById('Amount');
            if (nameEl) { setVal(nameEl, '\(js(name))'); } else { missing.push('CRN1'); }
            if (contactEl) { setVal(contactEl, '\(js(contact))'); } else { missing.push('CRN2'); }
            if (amountEl) { setVal(amountEl, '\(js(amount))'); } else { missing.push('Amount'); }
            if (missing.length) { return 'missing=' + missing.join(','); }
            return 'ok name=\\'' + nameEl.value + '\\'' +
                   ' contact=\\'' + contactEl.value + '\\'' +
                   ' amount=\\'' + amountEl.value + '\\'';
        })();
        """
    }

    /// Clicks the Visa or Mastercard logo DIV on the payer page, which fires the site's own
    /// `SubmitForm(dataType)` AJAX call and redirects to the card-entry page.
    /// - Parameter cardType: `"visa"` or `"mastercard"`, matched against `data-type`.
    /// - Returns: JS producing `clicked <type>` or `not_found available=visa|mastercard`.
    static func clickCardType(_ cardType: String) -> String {
        """
        (function() {
            \(helpers)
            var type = '\(js(cardType))';
            var logos = document.querySelectorAll('#cardlogos div');
            var target = null, available = [];
            for (var i = 0; i < logos.length; i++) {
                var dt = (logos[i].getAttribute('data-type') || '').toLowerCase();
                available.push(dt || '?');
                if (dt === type) { target = logos[i]; }
            }
            if (!target) { return 'not_found available=' + available.join('|'); }
            press(target);
            return 'clicked ' + type;
        })();
        """
    }

    // MARK: - Card page

    /// Reports whether the card-entry page is on screen, by looking for a visible
    /// card-number input. Used to wait out the AJAX redirect after the card-type click.
    /// - Returns: JS producing `ready` or `not_ready url=<path>`.
    static var cardPageReady: String {
        """
        (function() {
            \(helpers)
            var marks = ['card number', 'cardnumber', 'cardno', 'card_num', 'card-number',
                         'cc-num', 'ccnumber', 'cc-number'];
            var inputs = document.querySelectorAll('input');
            for (var i = 0; i < inputs.length; i++) {
                if (!visible(inputs[i])) { continue; }
                var a = attrs(inputs[i]);
                for (var j = 0; j < marks.length; j++) {
                    if (a.indexOf(marks[j]) !== -1) { return 'ready'; }
                }
            }
            return 'not_ready url=' + location.pathname;
        })();
        """
    }

    /// Fills the card-entry page: card number, separate MM and YY boxes (falling back to a
    /// single combined expiry field), and CVN. Fields are located resiliently by
    /// id/name/aria/placeholder/autocomplete — the card page is rendered after a redirect
    /// and its exact IDs are not part of the static HTML.
    /// - Parameters:
    ///   - card: digits only.
    ///   - mm: month digits.
    ///   - yy: two-digit year digits.
    ///   - cvn: CVV digits.
    /// - Returns: JS producing `ok card=1 mm=1 yy=1 cvn=1` (or `expiry=combined`) or
    ///   `missing=card,mm`.
    static func fillCardDetails(card: String, mm: String, yy: String, cvn: String) -> String {
        """
        (function() {
            \(helpers)
            function find(marks, exclude) {
                var inputs = document.querySelectorAll('input');
                for (var i = 0; i < inputs.length; i++) {
                    var el = inputs[i];
                    if (!visible(el)) { continue; }
                    var a = attrs(el);
                    var bad = false;
                    for (var k = 0; k < exclude.length; k++) {
                        if (a.indexOf(exclude[k]) !== -1) { bad = true; break; }
                    }
                    if (bad) { continue; }
                    for (var j = 0; j < marks.length; j++) {
                        if (a.indexOf(marks[j]) !== -1) { return el; }
                    }
                }
                return null;
            }

            var filled = [], missing = [];
            var CARD = '\(js(card))', MM = '\(js(mm))', YY = '\(js(yy))', CVN = '\(js(cvn))';

            var cardEl = find(['card number', 'cardnumber', 'cardno', 'card_num',
                               'card-number', 'cc-num', 'ccnumber', 'cc-number'], []);
            if (cardEl) { setVal(cardEl, CARD); filled.push('card=1'); } else { missing.push('card'); }

            // Exclusion keeps 'MM' from matching inside e.g. an id like 'Amount_mm' leftovers
            // and keeps the card-number field from matching the month patterns.
            var cardGuard = ['card'];
            var mmEl = find(['expirymonth', 'expiry-month', 'expmonth', 'exp-month',
                             'cc-exp-month', 'expiry month', 'mm-expire', 'month'],
                            cardGuard.concat(['year', 'yy']));
            var yyEl = find(['expiryyear', 'expiry-year', 'expyear', 'exp-year',
                             'cc-exp-year', 'expiry year', 'year'],
                            cardGuard.concat(['month', 'mm']));
            if (mmEl && yyEl) {
                setVal(mmEl, MM); setVal(yyEl, YY);
                filled.push('mm=1', 'yy=1');
            } else {
                // Single combined expiry field (MM/YY).
                var expEl = find(['cc-exp', 'expiry', 'expiration', 'exp date'],
                                 cardGuard);
                if (expEl) {
                    setVal(expEl, MM + '/' + YY);
                    filled.push('expiry=combined');
                    if (!mmEl) { mmEl = expEl; }
                    if (!yyEl) { yyEl = expEl; }
                } else {
                    if (!mmEl) { missing.push('mm'); }
                    if (!yyEl) { missing.push('yy'); }
                }
            }

            var cvnEl = find(['cvn', 'cvv', 'cvc', 'security'], cardGuard);
            if (cvnEl) { setVal(cvnEl, CVN); filled.push('cvn=1'); } else { missing.push('cvn'); }

            if (missing.length) { return 'missing=' + missing.join(','); }
            return 'ok ' + filled.join(' ');
        })();
        """
    }

    // MARK: - Human verification

    /// Reports the state of the human-verification widget.
    /// - Returns: JS producing `verified`, `unticked`, `iframe` (widget lives in a
    ///   cross-origin frame), or `absent` (no verification on this page).
    static var captchaState: String {
        """
        (function() {
            var ta = document.querySelector(
                'textarea[name="h-captcha-response"], textarea[name="g-recaptcha-response"]');
            if (ta && ta.value && ta.value.length > 10) { return 'verified'; }

            var boxes = document.querySelectorAll('input[type="checkbox"], [role="checkbox"]');
            for (var i = 0; i < boxes.length; i++) {
                var el = boxes[i];
                var wrap = el.closest('label, li, div, form');
                var hay = ((el.id || '') + ' ' + (el.name || '') + ' ' +
                           (el.getAttribute('aria-label') || '') + ' ' +
                           ((wrap && wrap.innerText) || '')).toLowerCase();
                if (hay.indexOf('human') !== -1 || hay.indexOf('robot') !== -1 ||
                    hay.indexOf('captcha') !== -1 || hay.indexOf('verification') !== -1 ||
                    hay.indexOf('not a robot') !== -1) {
                    var ticked = el.checked === true || el.getAttribute('aria-checked') === 'true';
                    return ticked ? 'verified' : 'unticked';
                }
            }

            if (document.querySelector('.h-captcha, .g-recaptcha, [data-sitekey], ' +
                'iframe[src*="hcaptcha"], iframe[src*="recaptcha"]')) { return 'iframe'; }
            return 'absent';
        })();
        """
    }

    /// Attempts to tick the human-verification box from the main frame.
    /// Works only when the checkbox is a main-frame element; the real hCaptcha checkbox is
    /// inside a cross-origin iframe and can only be tapped by the user in the Live tab.
    /// - Returns: JS producing the same values as `captchaState`, or `clicked` /
    ///   `clicked_failed` for a main-frame attempt.
    static var clickCaptcha: String {
        """
        (function() {
            var ta = document.querySelector(
                'textarea[name="h-captcha-response"], textarea[name="g-recaptcha-response"]');
            if (ta && ta.value && ta.value.length > 10) { return 'verified'; }

            var boxes = document.querySelectorAll('input[type="checkbox"], [role="checkbox"]');
            var target = null;
            for (var i = 0; i < boxes.length; i++) {
                var el = boxes[i];
                var wrap = el.closest('label, li, div, form');
                var hay = ((el.id || '') + ' ' + (el.name || '') + ' ' +
                           (el.getAttribute('aria-label') || '') + ' ' +
                           ((wrap && wrap.innerText) || '')).toLowerCase();
                if (hay.indexOf('human') !== -1 || hay.indexOf('robot') !== -1 ||
                    hay.indexOf('captcha') !== -1 || hay.indexOf('verification') !== -1 ||
                    hay.indexOf('not a robot') !== -1) {
                    if (el.checked === true || el.getAttribute('aria-checked') === 'true') {
                        return 'verified';
                    }
                    target = el;
                    break;
                }
            }

            if (target) {
                try { target.click(); } catch (e) {}
                target.dispatchEvent(new Event('input', {bubbles: true}));
                target.dispatchEvent(new Event('change', {bubbles: true}));
                var nowTicked = target.checked === true ||
                                target.getAttribute('aria-checked') === 'true';
                return nowTicked ? 'verified' : 'clicked_failed';
            }

            if (document.querySelector('.h-captcha, .g-recaptcha, [data-sitekey], ' +
                'iframe[src*="hcaptcha"], iframe[src*="recaptcha"]')) { return 'iframe'; }
            return 'absent';
        })();
        """
    }

    // MARK: - Cross-frame captcha pressing

    /// Injected into **every** frame (`forMainFrameOnly: false`) so it also runs inside the
    /// cross-origin hCaptcha/reCAPTCHA iframe that ordinary page scripts cannot reach.
    ///
    /// Inside a captcha frame it locates the anchor checkbox and presses it with a full
    /// touch/pointer/mouse sequence, retrying a few times while it stays unchecked, and
    /// reports progress to native through the `rorkCaptcha` message handler.
    /// No-ops in every other frame.
    static var captchaAutoPressUserScript: String {
        """
        (function() {
            if (window.__rorkCaptchaAuto) { return; }
            var href = '';
            try { href = location.href || ''; } catch (e) { return; }
            if (href.indexOf('hcaptcha.com') === -1 && href.indexOf('recaptcha') === -1) {
                return;
            }
            window.__rorkCaptchaAuto = true;

            function report(msg) {
                try { window.webkit.messageHandlers.rorkCaptcha.postMessage(msg); } catch (e) {}
            }
            function press(el) {
                try { el.scrollIntoView({behavior: 'instant', block: 'center'}); } catch (e) {}
                var r = el.getBoundingClientRect();
                var cx = r.left + r.width / 2, cy = r.top + r.height / 2;
                var opts = {bubbles: true, cancelable: true, view: window,
                            clientX: cx, clientY: cy, button: 0};
                try { el.focus(); } catch (e) {}
                try {
                    var touch = new Touch({identifier: Date.now(), target: el,
                                           clientX: cx, clientY: cy});
                    el.dispatchEvent(new TouchEvent('touchstart', {
                        bubbles: true, cancelable: true,
                        touches: [touch], targetTouches: [touch], changedTouches: [touch]}));
                    el.dispatchEvent(new TouchEvent('touchend', {
                        bubbles: true, cancelable: true,
                        touches: [], targetTouches: [], changedTouches: [touch]}));
                } catch (e) {}
                try { el.dispatchEvent(new PointerEvent('pointerdown', opts)); } catch (e) {}
                try { el.dispatchEvent(new MouseEvent('mousedown', opts)); } catch (e) {}
                try { el.dispatchEvent(new PointerEvent('pointerup', opts)); } catch (e) {}
                try { el.dispatchEvent(new MouseEvent('mouseup', opts)); } catch (e) {}
                try { el.dispatchEvent(new MouseEvent('click', opts)); } catch (e) {}
                try { el.click(); } catch (e) {}
            }
            function box() {
                return document.getElementById('checkbox') ||
                       document.querySelector('#recaptcha-anchor') ||
                       document.querySelector('.recaptcha-checkbox') ||
                       document.querySelector('[role="checkbox"]');
            }
            function checked(el) {
                return el.getAttribute('aria-checked') === 'true' ||
                       (el.className || '').indexOf('checked') !== -1;
            }

            var presses = 0, ticks = 0;
            var timer = setInterval(function() {
                ticks++;
                var el = box();
                if (!el) {
                    if (ticks > 60) { clearInterval(timer); }
                    return;
                }
                if (checked(el)) { clearInterval(timer); report('verified'); return; }
                // Press, then give the widget ~4s to answer before pressing again.
                if (ticks % 8 === 1) {
                    if (presses >= 3) { clearInterval(timer); return; }
                    presses++;
                    press(el);
                    report(presses === 1 ? 'pressed' : 'pressed_retry');
                }
            }, 500);
            report('found');
        })();
        """
    }

    /// Presses the captcha checkbox on demand. Evaluated by the engine directly inside a
    /// registered captcha frame via `evaluateJavaScript(_:in:contentWorld:)`.
    /// - Returns: JS producing `verified`, `pressed`, or `no_box`.
    static var tapCaptchaCheckbox: String {
        """
        (function() {
            \(helpers)
            var el = document.getElementById('checkbox') ||
                     document.querySelector('#recaptcha-anchor') ||
                     document.querySelector('.recaptcha-checkbox') ||
                     document.querySelector('[role="checkbox"]');
            if (!el) { return 'no_box'; }
            if (el.getAttribute('aria-checked') === 'true' ||
                (el.className || '').indexOf('checked') !== -1) { return 'verified'; }
            press(el);
            return 'pressed';
        })();
        """
    }

    // MARK: - Proceed

    /// Clicks the Proceed / Pay button on the card page. Uses the same innermost-label +
    /// hit-test approach that fixed the PPSR "Show my results" press: resolve what a finger
    /// would actually hit and dispatch a full touch/pointer/mouse sequence.
    /// - Parameter forceFormSubmit: escalates to an Enter key + `form.requestSubmit()`.
    /// - Returns: JS producing a diagnostic string describing what was pressed.
    static func clickProceed(forceFormSubmit: Bool = false) -> String {
        let force = forceFormSubmit ? "true" : "false"
        return """
        (function() {
            \(helpers)
            var FORCE = \(force);

            function labelOf(el) {
                return (el.innerText || el.textContent || el.value || '').trim().toLowerCase();
            }
            function matches(t) {
                var marks = ['proceed', 'pay now', 'make payment', 'submit payment',
                             'process payment', 'pay by card', 'pay'];
                for (var i = 0; i < marks.length; i++) {
                    if (t.indexOf(marks[i]) !== -1) { return true; }
                }
                return false;
            }
            function innermostLabelled() {
                var nodes = document.querySelectorAll('button, input[type="submit"], ' +
                    'input[type="button"], a[role="button"], [role="button"], a');
                for (var i = nodes.length - 1; i >= 0; i--) {
                    if (visible(nodes[i]) && matches(labelOf(nodes[i]))) { return nodes[i]; }
                }
                return null;
            }

            var btn = innermostLabelled();
            if (!btn) {
                var all = Array.prototype.slice.call(
                    document.querySelectorAll('button, input[type="submit"], ' +
                                              'input[type="button"]')).filter(visible);
                btn = all.length ? all[all.length - 1] : null;
            }
            if (!btn) { return 'no_proceed_button'; }

            // Re-run the site's validation so the form counts as complete.
            var fields = document.querySelectorAll('input, select, textarea');
            for (var i = 0; i < fields.length; i++) {
                var f = fields[i];
                if (f.value && f.type !== 'hidden') {
                    f.dispatchEvent(new Event('input', {bubbles: true}));
                    f.dispatchEvent(new Event('change', {bubbles: true}));
                    f.dispatchEvent(new Event('blur', {bubbles: true}));
                }
            }

            // Strip any disabled state left behind.
            try { btn.disabled = false; } catch (e) {}
            btn.removeAttribute('disabled');
            btn.removeAttribute('aria-disabled');

            press(btn);
            var info = 'tag=' + btn.tagName + ' label=\\'' +
                       labelOf(btn).substring(0, 24) + '\\'';

            if (FORCE) {
                var keyOpts = {bubbles: true, cancelable: true, key: 'Enter',
                               code: 'Enter', keyCode: 13, which: 13};
                try { btn.dispatchEvent(new KeyboardEvent('keydown', keyOpts)); } catch (e) {}
                try { btn.dispatchEvent(new KeyboardEvent('keypress', keyOpts)); } catch (e) {}
                try { btn.dispatchEvent(new KeyboardEvent('keyup', keyOpts)); } catch (e) {}
                var form = btn.form || btn.closest('form');
                if (form) {
                    try {
                        if (form.requestSubmit) { form.requestSubmit(); }
                        else { form.submit(); }
                        return 'clicked+enter+formSubmit [' + info + ']';
                    } catch (e) {}
                }
                return 'clicked+enter [' + info + ']';
            }
            return 'clicked [' + info + ']';
        })();
        """
    }

    // MARK: - Diagnostics

    /// Dumps every visible input on the current page so a failed card fill can be
    /// diagnosed from the debug log.
    /// - Returns: JS producing e.g. `inputs=CardNumber(text), ExpiryMonth(text), …`.
    static var fieldDump: String {
        """
        (function() {
            var out = [];
            var inputs = document.querySelectorAll('input, select, textarea');
            for (var i = 0; i < inputs.length && out.length < 10; i++) {
                var el = inputs[i];
                if (el.type === 'hidden') { continue; }
                var r = el.getBoundingClientRect();
                if (r.width === 0 && r.height === 0) { continue; }
                var name = el.id || el.name || el.getAttribute('aria-label') ||
                           el.placeholder || '?';
                if (name.length > 20) { name = name.substring(0, 20); }
                out.push(name + '(' + el.tagName.toLowerCase() + ')');
            }
            return 'inputs=' + (out.length ? out.join(', ') : 'none');
        })();
        """
    }

    // MARK: - Result state

    /// Reports what the page is doing after Proceed was pressed.
    /// - Returns: JS producing `reacted:processing`, `reacted:success`,
    ///   `reacted:error`, `reacted:done`, or `waiting`.
    ///
    /// Matched on purpose: only the receipt phrases Bpoint actually prints count as a
    /// result — "your payment was successful" / "your transaction was successful" go to the
    /// Successful list, "your payment was declined" / "your transaction was declined" are
    /// recorded as declines. If the terminal "Web payment result" page is on screen but says
    /// neither, `reacted:done` tells the engine the card is finished (recorded UNKNOWN) so it
    /// moves on instead of re-clicking into the receipt page.
    static var state: String {
        """
        (function() {
            var t = (document.body.innerText || '').toLowerCase();

            var processing = ['processing', 'please wait', 'validating', 'contacting'];
            for (var i = 0; i < processing.length; i++) {
                if (t.indexOf(processing[i]) !== -1) { return 'reacted:processing'; }
            }

            var success = ['your payment was successful',
                           'your transaction was successful'];
            for (var i = 0; i < success.length; i++) {
                if (t.indexOf(success[i]) !== -1) { return 'reacted:success'; }
            }

            var errors = ['your payment was declined', 'your transaction was declined',
                          'your payment was unsuccessful', 'your transaction was unsuccessful'];
            for (var i = 0; i < errors.length; i++) {
                if (t.indexOf(errors[i]) !== -1) { return 'reacted:error'; }
            }

            if (t.indexOf('web payment result') !== -1) { return 'reacted:done'; }

            return 'waiting';
        })();
        """
    }
}
