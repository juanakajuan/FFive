import SwiftUI
import UIKit

extension View {
    /// Hides the keyboard when the user taps anywhere outside a text input. The tap still reaches what it hit, so a
    /// button tapped while typing both closes the keyboard and acts.
    func dismissesKeyboardOnTapOutside() -> some View {
        background(KeyboardDismissInstaller().frame(width: 0, height: 0))
    }
}

/// Installs one tap recognizer on the hosting window, which also covers sheets and covers presented in it.
private struct KeyboardDismissInstaller: UIViewRepresentable {
    func makeUIView(context: Context) -> InstallerView { InstallerView() }
    func updateUIView(_ uiView: InstallerView, context: Context) {}

    final class InstallerView: UIView, UIGestureRecognizerDelegate {
        private lazy var recognizer: UITapGestureRecognizer = {
            let tap = UITapGestureRecognizer(target: self, action: #selector(tapped))
            tap.cancelsTouchesInView = false
            tap.delegate = self
            return tap
        }()

        override func didMoveToWindow() {
            super.didMoveToWindow()
            recognizer.view?.removeGestureRecognizer(recognizer)
            window?.addGestureRecognizer(recognizer)
        }

        @objc private func tapped() {
            window?.endEditing(true)
        }

        /// Skips touches on a text input, and on any alert: an alert owns its text field and buttons, and hiding the
        /// keyboard mid-tap recenters the alert so the touch ends off the button it began on.
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
            var view = touch.view
            while let current = view {
                if current is UITextField || current is UITextView || current.next is UIAlertController {
                    return false
                }
                view = current.superview
            }
            return true
        }

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer
        ) -> Bool { true }
    }
}
