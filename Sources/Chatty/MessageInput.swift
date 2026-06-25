import SwiftUI
import AppKit

/// A multi-line text input backed by `NSTextView`, so we get real macOS editing
/// behavior that a SwiftUI `TextField` can't give us:
///   • Return              → submit (calls `onSubmit`)
///   • Shift/Option+Return → insert a newline
/// The view reports its laid-out height back through `calculatedHeight` so the
/// caller can grow the field with its content (and cap it, scrolling past that).
struct MessageInput: NSViewRepresentable {
    @Binding var text: String
    @Binding var calculatedHeight: CGFloat
    var onSubmit: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> NSScrollView {
        let textView = NSTextView()
        textView.delegate = context.coordinator
        textView.isRichText = false
        textView.font = .systemFont(ofSize: NSFont.systemFontSize)
        textView.allowsUndo = true
        textView.drawsBackground = false
        textView.textContainerInset = NSSize(width: 5, height: 7)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.textContainer?.widthTracksTextView = true
        textView.autoresizingMask = [.width]
        textView.string = text

        let scroll = NSScrollView()
        scroll.drawsBackground = false
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true
        scroll.borderType = .noBorder
        scroll.documentView = textView

        DispatchQueue.main.async { context.coordinator.recalcHeight(textView) }
        return scroll
    }

    func updateNSView(_ scroll: NSScrollView, context: Context) {
        guard let textView = scroll.documentView as? NSTextView else { return }
        // Keep the text view in sync when the model changes it externally
        // (e.g. cleared to "" after a message is sent).
        if textView.string != text {
            textView.string = text
            context.coordinator.recalcHeight(textView)
        }
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        let parent: MessageInput
        init(_ parent: MessageInput) { self.parent = parent }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            parent.text = textView.string
            recalcHeight(textView)
        }

        /// Intercept Return: plain Return submits, Shift/Option+Return makes a newline.
        func textView(_ textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                let flags = NSApp.currentEvent?.modifierFlags ?? []
                if flags.contains(.shift) || flags.contains(.option) {
                    textView.insertNewlineIgnoringFieldEditor(nil)
                } else {
                    parent.onSubmit()
                }
                return true
            }
            return false
        }

        /// Measure the laid-out text height and push it back to SwiftUI.
        func recalcHeight(_ textView: NSTextView) {
            guard let layoutManager = textView.layoutManager,
                  let container = textView.textContainer else { return }
            layoutManager.ensureLayout(for: container)
            let used = layoutManager.usedRect(for: container).height
            let height = used + textView.textContainerInset.height * 2
            if abs(parent.calculatedHeight - height) > 0.5 {
                DispatchQueue.main.async { self.parent.calculatedHeight = height }
            }
        }
    }
}
