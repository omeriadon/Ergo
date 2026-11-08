//
//  AskSelectableText.swift
//  Ergo
//
//  Created by Adon Omeri on 7/11/2026.
//

import ErgoMarkdown
import ErgoProtocol
import SwiftUI
import UIKit

/// Markdown blocks as one piece of text you can select across, lines and paragraphs included. SwiftUI's `Text` only
/// selects a whole `Text` at once, so this is a `UITextView`, used only for reading.
struct AskSelectableText: UIViewRepresentable {
	let blocks: [MarkdownDocument.Block]

	@Environment(\.openURL)
	private var openURL

	@Environment(\.dynamicTypeSize)
	private var dynamicTypeSize

	@Environment(NavigationManager.self)
	private var navigation

	@Environment(AskStore.self)
	private var store

	func makeUIView(context: Context) -> UITextView {
		let storage = NSTextStorage()
		let layoutManager = RoundedBackgroundLayoutManager()
		let container = NSTextContainer(size: CGSize(width: 0, height: CGFloat.greatestFiniteMagnitude))
		container.widthTracksTextView = true
		storage.addLayoutManager(layoutManager)
		layoutManager.addTextContainer(container)

		let view = UITextView(frame: .zero, textContainer: container)
		view.isEditable = false
		view.isSelectable = true
		view.isScrollEnabled = false
		view.backgroundColor = .clear
		view.textContainerInset = .zero
		view.textContainer.lineFragmentPadding = 0
		view.delegate = context.coordinator
		view.dataDetectorTypes = []
		view.linkTextAttributes = [.foregroundColor: UIColor.tintColor]
		// So holding on text selects it, rather than picking it up
		view.textDragInteraction?.isEnabled = false
		view.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
		return view
	}

	func updateUIView(_ view: UITextView, context: Context) {
		context.coordinator.openURL = openURL
		context.coordinator.navigation = navigation
		context.coordinator.store = store

		let traits = UITraitCollection(preferredContentSizeCategory: UIContentSizeCategory(dynamicTypeSize))
		let text = AskAttributedText(traits: traits).attributed(blocks)
		// Setting it again would lose a selection
		if view.attributedText != text {
			view.attributedText = text
		}
	}

	func sizeThatFits(_ proposal: ProposedViewSize, uiView: UITextView, context _: Context) -> CGSize? {
		let width = proposal.width ?? uiView.bounds.width
		let fitted = uiView.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
		return CGSize(width: width, height: fitted.height)
	}

	func makeCoordinator() -> Coordinator {
		Coordinator()
	}

	final class Coordinator: NSObject, UITextViewDelegate {
		var openURL: OpenURLAction?
		var navigation: NavigationManager?
		var store: AskStore?

		/// The app's own links run here, so they never go out to the system and back
		func textView(_: UITextView, primaryActionFor textItem: UITextItem, defaultAction: UIAction) -> UIAction? {
			guard case let .link(url) = textItem.content else { return defaultAction }
			return UIAction { [weak self] _ in
				guard let self else { return }
				if let intent = AskIntent(url: url) {
					if let navigation, let store {
						AskIntents.run(intent, navigation: navigation, store: store)
					}
				} else {
					openURL?(url)
				}
			}
		}
	}
}

// MARK: - Building the text

extension NSAttributedString.Key {
	static let roundedBackground = NSAttributedString.Key("ErgoRoundedBackground")
}

final class RoundedBackgroundLayoutManager: NSLayoutManager {
	var cornerRadius: CGFloat = 5
	var horizontalInset: CGFloat = 2

	override func drawBackground(forGlyphRange glyphsToShow: NSRange, at origin: CGPoint) {
		super.drawBackground(forGlyphRange: glyphsToShow, at: origin)

		guard let textStorage else { return }

		let characterRange = characterRange(forGlyphRange: glyphsToShow, actualGlyphRange: nil)

		textStorage.enumerateAttribute(.roundedBackground, in: characterRange) { value, range, _ in
			guard let color = value as? UIColor else { return }

			let glyphRange = self.glyphRange(forCharacterRange: range, actualCharacterRange: nil)

			self.enumerateLineFragments(forGlyphRange: glyphRange) { _, _, container, lineGlyphRange, _ in
				let intersection = NSIntersectionRange(glyphRange, lineGlyphRange)
				guard intersection.length > 0 else { return }

				var rect = self.boundingRect(forGlyphRange: intersection, in: container)
				rect.origin.x += origin.x
				rect.origin.y += origin.y
				rect = rect.insetBy(dx: -self.horizontalInset, dy: 0)

				color.setFill()
				UIBezierPath(roundedRect: rect, cornerRadius: self.cornerRadius).fill()
			}
		}
	}
}

/// Links this app can't follow stay as plain words, since the server's library can be newer than this one
@MainActor
enum AskMarkdownLinks {
	static func canOpen(_ url: URL) -> Bool {
		guard let intent = AskIntent(url: url) else { return true }
		return AskIntents.canRun(intent)
	}
}
