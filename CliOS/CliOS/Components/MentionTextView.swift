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
}

// MARK: - MentionTextView

struct MentionTextView: UIViewRepresentable {
    @Binding var text: String
    @Binding var isFocused: Bool
    var placeholder: String = "Message"
    var textColor: UIColor = .white
    var tintColor: UIColor = .white
    var font: UIFont = .systemFont(ofSize: 16)
    var maxLines: Int = 6
    var controller: MentionTextController?

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> UITextView {
        let tv = UITextView()
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

        func textViewDidChange(_ tv: UITextView) {
            parent.text = tv.text
            updatePlaceholder(tv)
            tv.invalidateIntrinsicContentSize()
        }

        func textViewDidBeginEditing(_ tv: UITextView) {
            DispatchQueue.main.async { self.parent.isFocused = true }
        }

        func textViewDidEndEditing(_ tv: UITextView) {
            DispatchQueue.main.async { self.parent.isFocused = false }
        }
    }
}
