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

/// What the blocks look like, as one attributed string
struct AskAttributedText {
	let traits: UITraitCollection

	func attributed(_ blocks: [MarkdownDocument.Block]) -> NSAttributedString {
		let text = NSMutableAttributedString()
		append(blocks, to: text, depth: 0, color: .label, marker: nil)
		// The last paragraph's line break would add an empty line
		if text.string.hasSuffix("\n") {
			text.deleteCharacters(in: NSRange(location: text.length - 1, length: 1))
		}
		return text
	}

	/// `marker` goes on the first block, for a list item
	private func append(_ blocks: [MarkdownDocument.Block], to text: NSMutableAttributedString, depth: Int, color: UIColor, marker: String?) {
		var marker = marker
		for block in blocks {
			defer { marker = nil }
			switch block {
				case let .heading(level, inline):
					let style = paragraph(depth: depth, hasMarker: marker != nil, spacingBefore: 8)
					appendLine(inline, to: text, font: font(heading: level), color: color, style: style, marker: marker)

				case let .paragraph(inline):
					appendLine(inline, to: text, font: font(.body), color: color, style: paragraph(depth: depth, hasMarker: marker != nil), marker: marker)

				case let .math(inline):
					let style = paragraph(depth: depth, hasMarker: marker != nil)
					if depth == 0 {
						style.alignment = .center
					}

					appendLine(
						inline,
						to: text,
						font: font(.body),
						color: color,
						style: style,
						marker: marker,
						highlightsInline: false
					)

				case let .list(ordered, items):
					for (index, item) in items.enumerated() {
						append(item, to: text, depth: depth + 1, color: color, marker: ordered ? "\(index + 1)." : "•")
					}

				case let .quote(inner):
					append(inner, to: text, depth: depth + 1, color: .secondaryLabel, marker: nil)

				case let .code(_, code):
					// Only inside a list or a quote: on their own, code blocks get their own view
					appendLine(AttributedString(code), to: text, font: monospaced(.footnote), color: color, style: paragraph(depth: depth, hasMarker: marker != nil), marker: marker)

				case let .table(header, rows):
					for row in [header] + rows {
						let line = row.map { String($0.characters) }.joined(separator: "   ")
						appendLine(AttributedString(line), to: text, font: font(.subheadline), color: color, style: paragraph(depth: depth, hasMarker: false), marker: nil)
					}

				case .rule:
					break
			}
		}
	}

	private func appendLine(
		_ inline: AttributedString,
		to text: NSMutableAttributedString,
		font base: UIFont,
		color: UIColor,
		style: NSParagraphStyle,
		marker: String?,
		highlightsInline: Bool = true
	) {
		let start = text.length

		if let marker {
			text.append(NSAttributedString(string: marker + "\t", attributes: [.font: base, .foregroundColor: UIColor.secondaryLabel]))
		}
		for run in inline.runs {
			text.append(
				NSAttributedString(
					string: String(inline[run.range].characters),
					attributes: attributes(of: run, base: base, color: color, highlightsInline: highlightsInline)
				)
			)
		}
		text.append(NSAttributedString(string: "\n", attributes: [.font: base]))
		text.addAttribute(.paragraphStyle, value: style, range: NSRange(location: start, length: text.length - start))
	}

	private static let mathStroke = -1.5
	private static let indent = 22.0
	private static let mathBackground = UIColor.systemGray6
	private static let codeBackground = UIColor.systemGray5

	private func attributes(
		of run: AttributedString.Runs.Run,
		base: UIFont,
		color: UIColor,
		highlightsInline: Bool
	) -> [NSAttributedString.Key: Any] {
		var attributes: [NSAttributedString.Key: Any] = [.font: base, .foregroundColor: color]

		if let script = run[MarkdownMathAttribute.self] {
			let size = script == 0 ? base.pointSize * 1.05 : base.pointSize * 0.75
			attributes[.font] = UIFont.monospacedSystemFont(ofSize: size, weight: .regular)
			attributes[.strokeWidth] = Self.mathStroke
			if highlightsInline {
				attributes[.roundedBackground] = Self.mathBackground
			}
			if script != 0 {
				attributes[.baselineOffset] = base.pointSize * (script > 0 ? 0.35 : -0.2)
			}
			return attributes
		}

		if let intent = run.inlinePresentationIntent {
			if intent.contains(.code) {
				attributes[.font] = UIFont.monospacedSystemFont(ofSize: base.pointSize * 0.92, weight: .regular)
				if highlightsInline {
					attributes[.roundedBackground] = Self.codeBackground
				}
			} else {
				var symbolic: UIFontDescriptor.SymbolicTraits = base.fontDescriptor.symbolicTraits
				if intent.contains(.stronglyEmphasized) {
					symbolic.insert(.traitBold)
				}
				if intent.contains(.emphasized) {
					symbolic.insert(.traitItalic)
				}
				// The rounded design has no italic, so that falls back to the plain one
				let descriptor = base.fontDescriptor.withSymbolicTraits(symbolic)
					?? UIFont.systemFont(ofSize: base.pointSize).fontDescriptor.withSymbolicTraits(symbolic)
				if let descriptor {
					attributes[.font] = UIFont(descriptor: descriptor, size: base.pointSize)
				}
			}
			if intent.contains(.strikethrough) {
				attributes[.strikethroughStyle] = NSUnderlineStyle.single.rawValue
			}
		}

		if let url = run.link, AskMarkdownLinks.canOpen(url) {
			attributes[.link] = url
		}
		return attributes
	}

	// MARK: - Styles

	private func paragraph(depth: Int, hasMarker: Bool, spacingBefore: CGFloat = 0) -> NSMutableParagraphStyle {
		let style = NSMutableParagraphStyle()
		let indent = CGFloat(depth) * Self.indent
		style.headIndent = indent
		style.firstLineHeadIndent = hasMarker ? indent - Self.indent : indent
		style.tabStops = [NSTextTab(textAlignment: .left, location: indent)]
		style.paragraphSpacing = 10
		style.paragraphSpacingBefore = spacingBefore
		style.lineSpacing = 2
		return style
	}

	/// Rounded, like the rest of the app
	private func font(_ style: UIFont.TextStyle) -> UIFont {
		let base = UIFont.preferredFont(forTextStyle: style, compatibleWith: traits)
		guard let rounded = base.fontDescriptor.withDesign(.rounded) else { return base }
		return UIFont(descriptor: rounded, size: base.pointSize)
	}

	private func font(heading level: Int) -> UIFont {
		let style: UIFont.TextStyle = switch level {
			case 1: .title2
			case 2: .title3
			default: .headline
		}
		let base = font(style)
		guard let bold = base.fontDescriptor.withSymbolicTraits(.traitBold) else { return base }
		return UIFont(descriptor: bold, size: base.pointSize)
	}

	private func monospaced(_ style: UIFont.TextStyle) -> UIFont {
		UIFont.monospacedSystemFont(ofSize: UIFont.preferredFont(forTextStyle: style, compatibleWith: traits).pointSize, weight: .regular)
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
