//
//  FindBar.swift
//  Ergo
//
//  Created by Adon Omeri on 10/11/2026.
//

import SwiftUI

extension EnvironmentValues {
	/// What's being looked for, for text below to mark where it appears
	@Entry var findHighlight: String?
}

/// What's being looked for on the open screen, and which of the matches is showing
struct FindState: Equatable {
	nonisolated static let options: String.CompareOptions = [.caseInsensitive, .diacriticInsensitive]

	var text = "" {
		didSet {
			if text != oldValue {
				index = 0
			}
		}
	}

	private(set) var index = 0

	var query: String {
		text.trimmingCharacters(in: .whitespacesAndNewlines)
	}

	/// Matches come and go while it's open, so the index may have run off the end
	func position(among count: Int) -> Int {
		min(index, max(count - 1, 0))
	}

	func current<Match>(in matches: [Match]) -> Match? {
		matches.isEmpty ? nil : matches[position(among: matches.count)]
	}

	/// Wraps around at both ends
	mutating func step(by offset: Int, among count: Int) {
		guard count > 0 else { return }
		index = (position(among: count) + offset + count) % count
	}
}

nonisolated extension String {
	func matchesFind(_ query: String) -> Bool {
		range(of: query, options: FindState.options) != nil
	}

	fileprivate func findRanges(of query: String) -> [Range<Index>] {
		var ranges: [Range<Index>] = []
		var rest = startIndex ..< endIndex
		while let match = range(of: query, options: FindState.options, range: rest) {
			ranges.append(match)
			rest = match.upperBound ..< endIndex
		}
		return ranges
	}
}

extension AttributedString {
	/// With every appearance of what's being looked for in orange
	func findHighlighted(_ query: String?) -> AttributedString {
		guard let query, !query.isEmpty else { return self }

		var ranges: [Range<Index>] = []
		var rest = startIndex ..< endIndex
		while let match = self[rest].range(of: query, options: FindState.options) {
			ranges.append(match)
			rest = match.upperBound ..< endIndex
		}

		var highlighted = self
		for range in ranges {
			highlighted[range].backgroundColor = .orange
		}
		return highlighted
	}
}

#if os(iOS)
	extension NSAttributedString {
		/// With every appearance of what's being looked for in orange
		func findHighlighted(_ query: String?) -> NSAttributedString {
			guard let query, !query.isEmpty else { return self }

			let highlighted = NSMutableAttributedString(attributedString: self)
			for range in string.findRanges(of: query) {
				highlighted.addAttribute(.roundedBackground, value: UIColor.systemOrange, range: NSRange(range, in: string))
			}
			return highlighted
		}
	}
#endif

extension View {
	/// On iOS the find bar takes the navigation bar's place. A Mac window's toolbar also holds the sidebar button and the
	/// window's own controls, so it stays, and the find bar sits under it.
	func toolbarHiddenWhileFinding(_ isFinding: Bool) -> some View {
		#if os(iOS)
			toolbarVisibility(isFinding ? .hidden : .automatic, for: .navigationBar)
		#else
			self
		#endif
	}
}

/// `.searchable` always leaves a field or a button on screen, and this only appears when Search is chosen from a menu
struct FindBar: View {
	@Binding var find: FindState?
	let prompt: LocalizedStringKey
	let count: Int

	/// Matches are newest first, so going up the screen is going forward through them
	var isNewestFirst = false

	@Environment(\.accessibilityReduceMotion)
	private var reduceMotion

	@FocusState private var isFocused: Bool

	private var text: Binding<String> {
		Binding(
			get: { find?.text ?? "" },
			set: { find?.text = $0 }
		)
	}

	private var hasQuery: Bool {
		find?.query.isEmpty == false
	}

	private var result: LocalizedStringKey {
		count == 0 ? "None" : "\((find?.position(among: count) ?? 0) + 1) of \(count)"
	}

	var body: some View {
		GlassEffectContainer(spacing: 1) {
			HStack(spacing: 8) {
				field

				Button("Previous", systemImage: "chevron.up") {
					find?.step(by: isNewestFirst ? 1 : -1, among: count)
				}
				.modifier(FindBarButton())
				.disabled(count < 2)
				.accessibilityIdentifier("find.previous")

				Button("Next", systemImage: "chevron.down") {
					find?.step(by: isNewestFirst ? -1 : 1, among: count)
				}
				.modifier(FindBarButton())
				.disabled(count < 2)
				.accessibilityIdentifier("find.next")

				Button("Close", systemImage: "xmark") {
					withAnimation(reduceMotion ? nil : .smooth) {
						find = nil
					}
				}
				.modifier(FindBarButton())
				.accessibilityIdentifier("find.close")
			}
			.padding(.horizontal, 16)
			.padding(.vertical, 6)
		}
		.task {
			isFocused = true
		}
	}

	private var field: some View {
		HStack(spacing: 6) {
			Image(systemName: "magnifyingglass")
				.foregroundStyle(.secondary)
				.accessibilityHidden(true)

			TextField(prompt, text: text)
				.focused($isFocused)
				.autocorrectionDisabled()
				.textInputAutocapitalization(.never)
				.submitLabel(.search)
				.onSubmit {
					find?.step(by: 1, among: count)
				}
				.accessibilityIdentifier("find.field")

			if hasQuery {
				Text(result)
					.font(.subheadline)
					.monospacedDigit()
					.foregroundStyle(.secondary)
					.lineLimit(1)
					.fixedSize()
			}
		}
		.padding(.horizontal, 14)
		.padding(.vertical, 10)
		.glassEffect(.regular.interactive(), in: Capsule())
	}
}

private struct FindBarButton: ViewModifier {
	func body(content: Content) -> some View {
		content
			.labelStyle(.iconOnly)
			.buttonStyle(.glass)
			.buttonBorderShape(.circle)
	}
}
