//
//  CanvasArrowNote.swift
//  Ergo
//
//  Created by Adon Omeri on 10/11/2026.
//

#if os(iOS)
	import UIKit

	/// A small label on an arrow the analysis has something to say about. Tapping it opens what it wrote. A plain button
	/// rather than hosted SwiftUI, since it has to follow the arrow on every frame of a drag.
	final class CanvasArrowNote: UIButton {
		private static let size = CGSize(width: 92, height: 26)

		init(tapped: @escaping () -> Void) {
			super.init(frame: CGRect(origin: .zero, size: Self.size))
			addAction(UIAction { _ in tapped() }, for: .touchUpInside)
			accessibilityHint = "Shows what the analysis found"
		}

		@available(*, unavailable)
		required init?(coder _: NSCoder) {
			fatalError("Use init(tapped:)")
		}

		func show(title: String, tint: UIColor) {
			var look = UIButton.Configuration.filled()
			look.cornerStyle = .capsule
			look.baseBackgroundColor = tint
			look.baseForegroundColor = .white
			look.title = title
			look.titleLineBreakMode = .byTruncatingTail
			look.contentInsets = NSDirectionalEdgeInsets(top: 2, leading: 8, bottom: 2, trailing: 8)
			look.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attributes in
				var attributes = attributes
				let font = UIFont.systemFont(ofSize: 12, weight: .semibold)
				attributes.font = font.fontDescriptor.withDesign(.rounded).map { UIFont(descriptor: $0, size: 12) } ?? font
				return attributes
			}
			configuration = look
		}
	}
#endif
