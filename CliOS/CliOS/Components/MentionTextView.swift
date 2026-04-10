import Combine
import SwiftUI
import UIKit

// MARK: - Controller (bridge for inserting mentions from SwiftUI)

@MainActor
final class MentionTextController: ObservableObject {
    weak var textView: UITextView?

    func insertMention(type: EntityType, entityId: String, name: String) {
        guard let tv = textView else { return }
        let font = tv.font ?? .systemFont(ofSize: 16)
        let textColor = tv.textColor ?? .white

        let mutable = NSMutableAttributedString(attributedString: tv.attributedText)
        let cursor = tv.selectedRange.location

        let mention = NSMutableAttributedString()

        // Space before if needed
        if cursor > 0 {
            let prev = (mutable.string as NSString).substring(with: NSRange(location: cursor - 1, length: 1))
            if prev != " " && prev != "\n" {
                mention.append(NSAttributedString(string: " ", attributes: [.font: font, .foregroundColor: textColor]))
            }
        }

        // Mention chip (single \u{FFFC} character with rendered pill image)
        let attachment = MentionAttachment(type: type, entityId: entityId, displayName: name, font: font)
        mention.append(NSAttributedString(attachment: attachment))

        // Space after with default typing style
        mention.append(NSAttributedString(string: " ", attributes: [
            .foregroundColor: textColor,
            .font: font,
        ]))

        mutable.insert(mention, at: cursor)
        tv.attributedText = mutable
        tv.selectedRange = NSRange(location: cursor + mention.length, length: 0)
        tv.typingAttributes = [.font: font, .foregroundColor: textColor]

        tv.delegate?.textViewDidChange?(tv)
    }

    /// Replace the @query text at `range` with a mention chip for the given entity.
    func replaceMention(range: NSRange, entity: EntityItem) {
        guard let tv = textView else { return }
        let font = tv.font ?? .systemFont(ofSize: 16)
        let textColor = tv.textColor ?? .white

        let mutable = NSMutableAttributedString(attributedString: tv.attributedText)

        let attachment = MentionAttachment(type: entity.type, entityId: entity.id, displayName: entity.name, font: font)
        let mentionStr = NSMutableAttributedString(attachment: attachment)
        mentionStr.append(NSAttributedString(string: " ", attributes: [.font: font, .foregroundColor: textColor]))

        mutable.replaceCharacters(in: range, with: mentionStr)
        tv.attributedText = mutable
        tv.selectedRange = NSRange(location: range.location + mentionStr.length, length: 0)
        tv.typingAttributes = [.font: font, .foregroundColor: textColor]

        tv.delegate?.textViewDidChange?(tv)
    }
}

// MARK: - MentionTextView

// MARK: - UITextView subclass for copy/paste mention fallback

private class MentionUITextView: UITextView {
    override func copy(_ sender: Any?) {
        let attr = attributedText ?? NSAttributedString()
        let plain = Self.plainTextWithMentions(from: attr, selectedRange: selectedRange)
        UIPasteboard.general.string = plain
    }

    static func plainTextWithMentions(from attr: NSAttributedString, selectedRange: NSRange) -> String {
        let range = selectedRange.length > 0
            ? selectedRange
            : NSRange(location: 0, length: attr.length)
        var result = ""
        attr.enumerateAttributes(in: range) { attrs, subRange, _ in
            if let mention = attrs[.attachment] as? MentionAttachment {
                result += "@\(mention.displayName)"
            } else {
                result += (attr.string as NSString).substring(with: subRange)
            }
        }
        return result
    }
}

struct MentionTextView: UIViewRepresentable {
    @Binding var text: String
    @Binding var isFocused: Bool
    var placeholder: String = "Message"
    var textColor: UIColor = .white
    var tintColor: UIColor = .white
    var font: UIFont = .systemFont(ofSize: 16)
    var maxLines: Int = 6
    var controller: MentionTextController?
    var mentionQuery: Binding<String?>?
    var mentionAnchorRange: Binding<NSRange?>?

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> UITextView {
        let tv = MentionUITextView()
        tv.delegate = context.coordinator
        tv.font = font
        tv.textColor = textColor
        tv.tintColor = tintColor
        tv.backgroundColor = .clear
        tv.isScrollEnabled = false
        tv.textContainerInset = .zero
        tv.textContainer.lineFragmentPadding = 0
        tv.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        tv.keyboardAppearance = .dark
        tv.typingAttributes = [.font: font, .foregroundColor: textColor]

        controller?.textView = tv
        context.coordinator.setupPlaceholder(in: tv)

        return tv
    }

    func updateUIView(_ tv: UITextView, context: Context) {
        context.coordinator.parent = self
        controller?.textView = tv

        if isFocused && !tv.isFirstResponder {
            DispatchQueue.main.async { tv.becomeFirstResponder() }
        } else if !isFocused && tv.isFirstResponder {
            tv.resignFirstResponder()
        }

        if text.isEmpty && tv.attributedText.length > 0 {
            tv.attributedText = NSAttributedString()
            tv.typingAttributes = [.font: font, .foregroundColor: textColor]
            context.coordinator.updatePlaceholder(tv)
            tv.invalidateIntrinsicContentSize()
        }

        let maxH = font.lineHeight * CGFloat(maxLines) + 1
        let fitsH = tv.sizeThatFits(CGSize(width: tv.bounds.width, height: .greatestFiniteMagnitude)).height
        let shouldScroll = fitsH > maxH
        if tv.isScrollEnabled != shouldScroll {
            tv.isScrollEnabled = shouldScroll
        }
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UITextView, context: Context) -> CGSize? {
        let w = proposal.width ?? uiView.bounds.width
        guard w > 0 else { return nil }
        let size = uiView.sizeThatFits(CGSize(width: w, height: .greatestFiniteMagnitude))
        let maxH = font.lineHeight * CGFloat(maxLines)
        return CGSize(width: size.width, height: max(font.lineHeight, min(size.height, maxH)))
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: MentionTextView
        private weak var placeholderLabel: UILabel?
        private var pendingDeleteRange: NSRange?

        init(parent: MentionTextView) {
            self.parent = parent
        }

        func setupPlaceholder(in tv: UITextView) {
            let label = UILabel()
            label.text = parent.placeholder
            label.font = parent.font
            label.textColor = parent.textColor.withAlphaComponent(0.35)
            label.translatesAutoresizingMaskIntoConstraints = false
            tv.addSubview(label)
            NSLayoutConstraint.activate([
                label.leadingAnchor.constraint(equalTo: tv.leadingAnchor),
                label.topAnchor.constraint(equalTo: tv.topAnchor),
            ])
            placeholderLabel = label
        }

        func updatePlaceholder(_ tv: UITextView) {
            placeholderLabel?.isHidden = tv.attributedText.length > 0
        }

        // MARK: - Atomic mention behavior

        func textView(_ tv: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
            let attr = tv.attributedText!

            // Backspace into a mention attachment
            if text.isEmpty && range.length == 1 && range.location < attr.length {
                if attr.attribute(.attachment, at: range.location, effectiveRange: nil) is MentionAttachment {
                    if pendingDeleteRange == range {
                        // Second backspace — allow deletion
                        pendingDeleteRange = nil
                        clearMentionHighlight(in: tv)
                        return true
                    }
                    // First backspace — highlight, block deletion
                    pendingDeleteRange = range
                    highlightMention(at: range, in: tv)
                    return false
                }
            }

            // Any other edit clears pending state
            if pendingDeleteRange != nil {
                clearMentionHighlight(in: tv)
                pendingDeleteRange = nil
            }
            return true
        }

        private func highlightMention(at range: NSRange, in tv: UITextView) {
            let mutable = NSMutableAttributedString(attributedString: tv.attributedText!)
            mutable.addAttribute(.backgroundColor, value: UIColor.systemRed.withAlphaComponent(0.3), range: range)
            let sel = tv.selectedRange
            tv.attributedText = mutable
            tv.selectedRange = sel
        }

        private func clearMentionHighlight(in tv: UITextView) {
            let mutable = NSMutableAttributedString(attributedString: tv.attributedText!)
            let fullRange = NSRange(location: 0, length: mutable.length)
            mutable.removeAttribute(.backgroundColor, range: fullRange)
            let sel = tv.selectedRange
            tv.attributedText = mutable
            tv.selectedRange = sel
        }

        func textViewDidChange(_ tv: UITextView) {
            pendingDeleteRange = nil
            parent.text = tv.text
            updatePlaceholder(tv)
            tv.invalidateIntrinsicContentSize()
            detectMentionTrigger(in: tv)
        }

        func textViewDidChangeSelection(_ tv: UITextView) {
            detectMentionTrigger(in: tv)
        }

        func textViewDidBeginEditing(_ tv: UITextView) {
            DispatchQueue.main.async { self.parent.isFocused = true }
        }

        func textViewDidEndEditing(_ tv: UITextView) {
            DispatchQueue.main.async { self.parent.isFocused = false }
        }

        // MARK: - @ Detection

        private func detectMentionTrigger(in tv: UITextView) {
            guard let queryBinding = parent.mentionQuery,
                  let rangeBinding = parent.mentionAnchorRange else { return }

            let text = tv.text ?? ""
            let cursor = tv.selectedRange.location
            guard cursor > 0, tv.selectedRange.length == 0 else {
                queryBinding.wrappedValue = nil
                return
            }

            let nsText = text as NSString
            var i = cursor - 1
            while i >= 0 {
                let ch = nsText.substring(with: NSRange(location: i, length: 1))
                if ch == "@" {
                    let validStart: Bool
                    if i == 0 {
                        validStart = true
                    } else {
                        let prev = nsText.substring(with: NSRange(location: i - 1, length: 1))
                        validStart = prev.rangeOfCharacter(from: .whitespacesAndNewlines) != nil
                            || prev == "\u{FFFC}"
                    }
                    if validStart {
                        queryBinding.wrappedValue = nsText.substring(
                            with: NSRange(location: i + 1, length: cursor - i - 1)
                        )
                        rangeBinding.wrappedValue = NSRange(location: i, length: cursor - i)
                        return
                    }
                }
                if ch == " " || ch == "\n" { break }
                i -= 1
            }
            queryBinding.wrappedValue = nil
        }
    }
}
