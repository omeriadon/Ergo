//
//  CheckTabView.swift
//  Ergo
//
//  Created by Adon Omeri on 1/11/2026.
//

import SwiftUI

struct CheckTabView: View {

	@Environment(NavigationManager.self)
	private var navigation

    var body: some View {
		VStack {
			Text("Hello, World!")

			Button {
				navigation.open(.analysis(id: "4trf"), from: .library)
			} label: {
				Text("rtefdv")
			}
		}
    }
}
