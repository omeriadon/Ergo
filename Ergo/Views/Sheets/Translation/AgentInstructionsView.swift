//
//  AgentInstructionsView.swift
//  Ergo
//
//  Created by Adon Omeri on 8/11/2026.
//

import Defaults
import ErgoProtocol
import SwiftUI

struct AgentInstructionsView: View {
	@Default(.agentInstructions) var instructions

	var body: some View {
		Form {
			Section {
				TextField("Instructions", text: $instructions, axis: .vertical)
					.lineLimit(5 ... 15)
					.accessibilityIdentifier("translation.instructions.field")
			} footer: {
				Text("Anything you'd like the agent to keep in mind when it answers or analyses a board, like being concise. It can change how it writes, but not what counts as a source. \(instructions.count) of \(AgentInstructions.characterLimit) characters.")
			}
		}
		.toolbarTitleVire("Instructions", "text.bubble")
		.onChange(of: instructions) {
			if instructions.count > AgentInstructions.characterLimit {
				instructions = String(instructions.prefix(AgentInstructions.characterLimit))
			}
		}
	}
}

#Preview {
	NavigationStack {
		AgentInstructionsView()
	}
	.environment(NavigationManager())
}
