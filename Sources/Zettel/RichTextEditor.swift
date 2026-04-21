import AppKit
import SwiftUI
import ZettelKit

struct RichTextEditor: NSViewRepresentable {
    let nodeID: UUID
    let data: Data?
    let focusOnPresent: Bool
    let onChange: (Data?) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onChange: onChange)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let textView = NSTextView()
        textView.delegate = context.coordinator
        textView.allowsUndo = true
        textView.isRichText = true
        textView.importsGraphics = true
        textView.isEditable = true
        textView.isSelectable = true
        textView.allowsImageEditing = true
        textView.drawsBackground = false
        textView.font = .systemFont(ofSize: 15)
        textView.textColor = .labelColor
        textView.textContainerInset = NSSize(width: 18, height: 20)
        textView.isHorizontallyResizable = false
        textView.isVerticallyResizable = true
        textView.autoresizingMask = [.width]
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainer?.lineFragmentPadding = 0
        textView.typingAttributes = [
            .font: NSFont.systemFont(ofSize: 15),
            .foregroundColor: NSColor.labelColor,
        ]

        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false
        scrollView.documentView = textView

        context.coordinator.textView = textView
        context.coordinator.apply(
            nodeID: nodeID,
            data: data,
            focusOnPresent: focusOnPresent,
            to: textView
        )

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = context.coordinator.textView else {
            return
        }

        context.coordinator.apply(
            nodeID: nodeID,
            data: data,
            focusOnPresent: focusOnPresent,
            to: textView
        )
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        let onChange: (Data?) -> Void
        weak var textView: NSTextView?
        private var lastNodeID: UUID?
        private var lastData: Data?
        private var isApplyingExternalUpdate = false

        init(onChange: @escaping (Data?) -> Void) {
            self.onChange = onChange
        }

        func textDidChange(_ notification: Notification) {
            publish()
        }

        func textDidEndEditing(_ notification: Notification) {
            publish()
        }

        func apply(
            nodeID: UUID,
            data: Data?,
            focusOnPresent: Bool,
            to textView: NSTextView
        ) {
            guard nodeID != lastNodeID || data != lastData else {
                return
            }

            isApplyingExternalUpdate = true
            textView.textStorage?.setAttributedString(AttributedTextArchive.decode(data))
            textView.typingAttributes = [
                .font: NSFont.systemFont(ofSize: 15),
                .foregroundColor: NSColor.labelColor,
            ]
            isApplyingExternalUpdate = false
            lastNodeID = nodeID
            lastData = data

            guard focusOnPresent else {
                return
            }

            DispatchQueue.main.async {
                guard textView.window != nil else {
                    return
                }

                textView.setSelectedRange(NSRange(location: textView.string.count, length: 0))
                textView.window?.makeFirstResponder(textView)
            }
        }

        private func publish() {
            guard !isApplyingExternalUpdate, let textView else {
                return
            }

            let nextData = AttributedTextArchive.encode(textView.attributedString())
            guard nextData != lastData else {
                return
            }

            lastData = nextData
            onChange(nextData)
        }
    }
}
