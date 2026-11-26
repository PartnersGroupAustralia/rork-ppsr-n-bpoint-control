import Foundation

/// JavaScript used to complete and submit the PPSR payment page.
///
/// Two faults made the automated submit a silent no-op:
/// 1. The page carries a required "…and acknowledge that:" confirmation box. PPSR refuses to
///    submit while it is unticked, without surfacing an error.
/// 2. The text "Show my results" lives on a wrapper `DIV`; pressing that wrapper does nothing
///    because the page binds its handler to the real control nested inside.
///
/// `tickConfirmations` fixes the first. `click` fixes the second by hit-testing the point at the
/// centre of the label — resolving the same element a finger would hit — and pressing that.
enum SubmitScript {

    // MARK: - Confirmation boxes

    /// Ticks any unticked confirmation / acknowledgement box on the payment page.
    ///
    /// Prefers boxes that are required or whose surrounding text reads like a declaration, and
    /// only falls back to ticking every visible box when none of those match. Supports both
    /// native `input[type=checkbox]` and ARIA custom checkboxes.
    /// - Returns: JS producing a diagnostic string such as `boxes=2 ticked=1 (declaration)`.
    static var tickConfirmations: String {
        """
        (function() {
            function visible(el) {
                if (!el) { return false; }
                var r = el.getBoundingClientRect();
                if (r.width === 0 && r.height === 0) {
                    // Custom checkboxes hide the real input and style a sibling instead.
                    var proxy = el.parentElement;
                    return !!(proxy && proxy.getBoundingClientRect().height > 0);
                }
                return true;
            }

            function contextText(el) {
                var parts = [];
                if (el.id) {
                    var lab = document.querySelector('label[for="' + el.id + '"]');
                    if (lab) { parts.push(lab.innerText || ''); }
                }
                var wrap = el.closest('label, .form-group, .checkbox, li, div');
                if (wrap) { parts.push(wrap.innerText || ''); }
                parts.push(el.getAttribute('aria-label') || '');
                parts.push(el.getAttribute('name') || '');
                parts.push(el.id || '');
                return parts.join(' ').toLowerCase();
            }

            var KEYWORDS = ['acknowledge', 'agree', 'terms', 'condition', 'declaration',
                            'declare', 'confirm', 'consent', 'accept', 'read and understood',
                            'privacy'];

            function isDeclaration(el) {
                if (el.required || el.getAttribute('aria-required') === 'true') { return true; }
                var t = contextText(el);
                for (var i = 0; i < KEYWORDS.length; i++) {
                    if (t.indexOf(KEYWORDS[i]) !== -1) { return true; }
                }
                return false;
            }

            function isTicked(el) {
                if (typeof el.checked === 'boolean' && el.tagName === 'INPUT') {
                    return el.checked;
                }
                return el.getAttribute('aria-checked') === 'true';
            }

            function tick(el) {
                if (el.tagName === 'INPUT') {
                    // Native click keeps the site's own handler in the loop and flips .checked.
                    try { el.click(); } catch (e) {}
                    if (!el.checked) {
                        el.checked = true;
                        el.dispatchEvent(new Event('input', {bubbles: true}));
                        el.dispatchEvent(new Event('change', {bubbles: true}));
                    }
                    return el.checked;
                }
                try { el.click(); } catch (e) {}
                if (el.getAttribute('aria-checked') !== 'true') {
                    el.setAttribute('aria-checked', 'true');
                    el.dispatchEvent(new Event('change', {bubbles: true}));
                }
                return el.getAttribute('aria-checked') === 'true';
            }

            var all = Array.prototype.slice.call(document.querySelectorAll(
                'input[type="checkbox"], [role="checkbox"]')).filter(visible);
            if (all.length === 0) { return 'boxes=0'; }

            var targets = all.filter(isDeclaration);
            var mode = 'declaration';
            if (targets.length === 0) { targets = all; mode = 'all'; }

            var ticked = 0;
            for (var i = 0; i < targets.length; i++) {
                if (!isTicked(targets[i]) && tick(targets[i])) { ticked++; }
            }

            var stillOff = all.filter(function(b) { return !isTicked(b); }).length;
            return 'boxes=' + all.length + ' ticked=' + ticked +
                   ' (' + mode + ')' + (stillOff ? ' STILL_UNTICKED=' + stillOff : '');
        })();
        """
    }

    // MARK: - Submit

    /// Builds the submit script.
    /// - Parameter forceFormSubmit: when true, escalates to `form.requestSubmit()` and an Enter
    ///   key press if the synthetic press produces no reaction.
    /// - Returns: JS producing a diagnostic string describing the control it pressed.
    static func click(forceFormSubmit: Bool) -> String {
        let force = forceFormSubmit ? "true" : "false"
        return """
        (function() {
            var FORCE = \(force);

            function visible(el) {
                return el && el.offsetWidth > 0 && el.offsetHeight > 0;
            }

            function labelOf(el) {
                return (el.innerText || el.textContent || el.value || '').trim().toLowerCase();
            }

            function matches(t) {
                return t.indexOf('show my result') !== -1 || t.indexOf('show results') !== -1;
            }

            // 1. Find the INNERMOST element carrying the label. Ancestors also "contain" the
            //    text, so taking the first match returns a useless wrapper DIV.
            function innermostLabelled() {
                var hits = [];
                var nodes = document.querySelectorAll('body *');
                for (var i = 0; i < nodes.length; i++) {
                    var el = nodes[i];
                    if (!visible(el)) { continue; }
                    if (!matches(labelOf(el))) { continue; }
                    // Keep only elements with no labelled descendant of their own.
                    var childHit = false;
                    for (var j = 0; j < el.children.length; j++) {
                        if (matches(labelOf(el.children[j]))) { childHit = true; break; }
                    }
                    if (!childHit) { hits.push(el); }
                }
                return hits.length ? hits[hits.length - 1] : null;
            }

            // 2. Resolve what a finger would actually hit at that spot, then climb to the
            //    nearest real control. This is the key fix: the handler lives on the control,
            //    not on the wrapper that happens to contain the words.
            function resolveTarget(labelEl) {
                var r = labelEl.getBoundingClientRect();
                var cx = r.left + r.width / 2;
                var cy = r.top + r.height / 2;
                var hit = document.elementFromPoint(cx, cy);
                var control = null;
                if (hit) {
                    control = hit.closest('button, input[type="submit"], input[type="button"], ' +
                                          'a, [role="button"]');
                }
                if (!control) {
                    control = labelEl.closest('button, input[type="submit"], a, [role="button"]');
                }
                if (!control) { control = labelEl.querySelector('button, input[type="submit"]'); }
                return control || hit || labelEl;
            }

            var labelEl = innermostLabelled();
            var btn = null;
            if (labelEl) {
                btn = resolveTarget(labelEl);
            } else {
                btn = document.querySelector('button[type="submit"], input[type="submit"]');
                if (!btn) {
                    var all = Array.prototype.slice.call(
                        document.querySelectorAll('button, input[type="submit"]')).filter(visible);
                    btn = all.length ? all[all.length - 1] : null;
                }
            }
            if (!btn) { return 'no_submit_button'; }

            // 3. Re-run the site's validation so the form counts as complete.
            var fields = document.querySelectorAll('input, select, textarea');
            for (var i = 0; i < fields.length; i++) {
                var f = fields[i];
                if (f.value) {
                    f.dispatchEvent(new Event('input', {bubbles: true}));
                    f.dispatchEvent(new Event('change', {bubbles: true}));
                    f.dispatchEvent(new Event('blur', {bubbles: true}));
                }
            }

            // 4. Bring the control on screen so the press is observable in the Live tab.
            window.scrollTo(0, document.body.scrollHeight);
            btn.scrollIntoView({behavior: 'instant', block: 'center'});

            var info = 'tag=' + btn.tagName +
                       ' type=' + (btn.getAttribute('type') || '-') +
                       ' disabled=' + (btn.disabled ? 'Y' : 'N') +
                       ' aria=' + (btn.getAttribute('aria-disabled') || '-');

            // 5. Strip any disabled state the site left behind.
            try { btn.disabled = false; } catch (e) {}
            btn.removeAttribute('disabled');
            btn.removeAttribute('aria-disabled');
            if (btn.classList) { btn.classList.remove('disabled'); }

            var r = btn.getBoundingClientRect();
            var cx = r.left + r.width / 2;
            var cy = r.top + r.height / 2;
            var opts = {bubbles: true, cancelable: true, view: window};
            opts.clientX = cx;
            opts.clientY = cy;
            opts.button = 0;

            try { btn.focus(); } catch (e) {}

            // Touch first — a mobile page may only bind touch handlers.
            try {
                var touch = new Touch({identifier: Date.now(), target: btn,
                                       clientX: cx, clientY: cy});
                btn.dispatchEvent(new TouchEvent('touchstart', {
                    bubbles: true, cancelable: true,
                    touches: [touch], targetTouches: [touch], changedTouches: [touch]}));
                btn.dispatchEvent(new TouchEvent('touchend', {
                    bubbles: true, cancelable: true,
                    touches: [], targetTouches: [], changedTouches: [touch]}));
            } catch (e) {}

            try { btn.dispatchEvent(new PointerEvent('pointerdown', opts)); } catch (e) {}
            try { btn.dispatchEvent(new MouseEvent('mousedown', opts)); } catch (e) {}
            try { btn.dispatchEvent(new PointerEvent('pointerup', opts)); } catch (e) {}
            try { btn.dispatchEvent(new MouseEvent('mouseup', opts)); } catch (e) {}
            try { btn.dispatchEvent(new MouseEvent('click', opts)); } catch (e) {}
            try { btn.click(); } catch (e) {}

            if (FORCE) {
                // Keyboard fallback — many payment forms submit on Enter.
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

    /// Dumps every plausible submit control on the page, so a failure to press can be diagnosed
    /// from the debug log rather than guessed at.
    static var candidateDump: String {
        """
        (function() {
            var nodes = document.querySelectorAll(
                'button, input[type="submit"], input[type="button"], a[role="button"], ' +
                '[role="button"]');
            var out = [];
            for (var i = 0; i < nodes.length && out.length < 8; i++) {
                var el = nodes[i];
                var r = el.getBoundingClientRect();
                if (r.width === 0 || r.height === 0) { continue; }
                var t = (el.innerText || el.value || '').trim().replace(/\\s+/g, ' ');
                if (t.length > 24) { t = t.substring(0, 24); }
                out.push(el.tagName + '(' + t + ')' + (el.disabled ? '[off]' : ''));
            }
            var boxes = document.querySelectorAll('input[type="checkbox"]');
            var unticked = 0;
            for (var i = 0; i < boxes.length; i++) {
                if (!boxes[i].checked) { unticked++; }
            }
            return 'candidates=' + (out.length ? out.join(', ') : 'none') +
                   ' | unticked_boxes=' + unticked;
        })();
        """
    }

    /// JS reporting whether the page has visibly reacted to the submit press.
    /// Returns a string starting with `reacted` once the press has demonstrably landed.
    ///
    /// This deliberately includes *terminal* answers. PPSR renders "Error in payment processing"
    /// inline while leaving the "Show my results" button on the page, so checking only for the
    /// button's disappearance made a declined card look like an unresponsive press and burned
    /// ~25s re-pressing a button that had already done its job.
    static var state: String {
        """
        (function() {
            var t = (document.body.innerText || '').toLowerCase();

            // Still working — keep waiting, do not re-press.
            var processing = ['processing payment', 'processing your payment',
                              'loading your results', 'loading results', 'please wait'];
            for (var i = 0; i < processing.length; i++) {
                if (t.indexOf(processing[i]) !== -1) { return 'reacted:processing'; }
            }
            // Terminal failure — the submit landed and PPSR has already answered.
            var errors = ['error in payment processing', 'payment declined',
                          'card was declined', 'card has been declined', 'transaction failed',
                          'may have been charged', 'insufficient funds', 'payment error',
                          'unable to process your payment'];
            for (var i = 0; i < errors.length; i++) {
                if (t.indexOf(errors[i]) !== -1) { return 'reacted:error'; }
            }

            // Terminal success — a real response page.
            var done = ['vehicle searched', 'your reference is', 'search number',
                        'vehicle details not found', 'download your search certificate'];
            for (var i = 0; i < done.length; i++) {
                if (t.indexOf(done[i]) !== -1) { return 'reacted:result'; }
            }

            if (location.href.toLowerCase().indexOf('/result') !== -1) {
                return 'reacted:url';
            }
            var nodes = document.querySelectorAll('button, input[type="submit"]');
            for (var i = 0; i < nodes.length; i++) {
                var label = (nodes[i].innerText || nodes[i].value || '').trim().toLowerCase();
                if (label.indexOf('show my result') !== -1) { return 'waiting'; }
            }
            return 'reacted:button_gone';
        })();
        """
    }
}
