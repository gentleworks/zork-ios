import SwiftUI
import UIKit

/// A read-only, selectable, auto-scrolling text view for terminal output.
struct TerminalTextView: UIViewRepresentable {

    let text: String

    func makeUIView(context: Context) -> UITextView {
        let tv = UITextView()
        tv.isEditable = false
        tv.isSelectable = true
        tv.backgroundColor = .black
        tv.textColor = .green
        tv.font = UIFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        tv.isScrollEnabled = true
        tv.textContainerInset = UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
        // Prevent the text view from shrinking the scroll area
        tv.contentInsetAdjustmentBehavior = .automatic
        return tv
    }

    func updateUIView(_ tv: UITextView, context: Context) {
        guard tv.text != text else { return }
        tv.text = text
        // Scroll to bottom after the layout pass
        DispatchQueue.main.async {
            let end = NSRange(location: tv.text.utf16.count, length: 0)
            tv.scrollRangeToVisible(end)
        }
    }
}
