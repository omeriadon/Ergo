//
//  HexColor.swift
//  ErgoKit
//
//  Created by Adon Omeri on 16/11/2026.
//

#if canImport(SwiftUI)
	import SwiftUI
#endif

/// A colour written by hand in a resource file as `#RRGGBB`, for content that picks its own colour rather than a
/// category's (`CategoryTheme`)
public struct HexColor: Hashable, Sendable {
	/// 0 to 1
	public let red: Double
	public let green: Double
	public let blue: Double

	/// Nil unless it's `#` and six hex digits
	public init?(_ text: String) {
		guard text.count == 7, text.first == "#", text.dropFirst().allSatisfy(\.isHexDigit), let value = UInt32(text.dropFirst(), radix: 16) else { return nil }
		red = Double((value >> 16) & 0xFF) / 255
		green = Double((value >> 8) & 0xFF) / 255
		blue = Double(value & 0xFF) / 255
	}

	#if canImport(SwiftUI)
		public var color: Color {
			Color(red: red, green: green, blue: blue)
		}

		/// The colour of `text`, or blue when it isn't one
		public static func color(_ text: String) -> Color {
			HexColor(text)?.color ?? .blue
		}
	#endif
}
