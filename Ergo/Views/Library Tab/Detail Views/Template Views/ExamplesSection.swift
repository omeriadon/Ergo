import SwiftUI

struct ExamplesSection: View {
	let list: [Example]
	var title = "Examples"

	var body: some View {
		if !list.isEmpty {
			VStack(alignment: .leading, spacing: 13) {
				Text(title)
					.textCase(.uppercase)
					.foregroundStyle(.accent)

				VStack(alignment: .leading, spacing: 4) {
					ForEach(list, id: \.text) { example in
						Text("-  \(example.text)")
							.textSelection(.enabled)
						if let note = example.note {
							Text("-  \(note)")
								.textSelection(.enabled)
								.padding(.leading, 30)
						}
					}
				}
			}
			.padding(12)
			.frame(maxWidth: .infinity, alignment: .leading)
			.background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
		}
	}
}
