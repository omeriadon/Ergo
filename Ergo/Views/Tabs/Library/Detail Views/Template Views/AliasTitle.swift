import SwiftUI

struct AliasTitle: View {
	let name: String
	let aliases: [String]

	@State private var showAliases = false

	var body: some View {
		Button {
			if !aliases.isEmpty {
				showAliases = true
			}
		} label: {
			Label(name, systemImage: "textformat.alt")
				.multilineTextAlignment(.leading)
				.labelStyle(.titleOnly)
				.foregroundStyle(.white)
				.font(.largeTitle.bold())
		}
		.accessibilityLabel(name)
		.accessibilityHint("Shows aliases")
		.accessibilityIdentifier("aliases.\(name)")
		.popover(isPresented: $showAliases) {
			VStack(alignment: .leading) {
				Text("Aliases")
					.font(.caption)
					.foregroundStyle(.secondary)
					.textCase(.uppercase)

				HStack(spacing: 45) {
					ForEach(aliases, id: \.self) { alias in
						Text(alias)
							.lineLimit(3)
							.minimumScaleFactor(0.1)
					}
				}
				.font(.system(.title2, design: .monospaced))
				.monospaced()
			}
			.padding()
			.foregroundStyle(.accent)
			.presentationCompactAdaptation(.popover)
		}
	}
}
