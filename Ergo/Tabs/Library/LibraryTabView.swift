//
//  LibraryTabView().swift
//  Ergo
//
//  Created by Adon Omeri on 1/11/2026.
//

import SwiftUI

struct LibraryTabView: View {

	@Environment(NavigationManager.self)
	private var navigation

    var body: some View {
		VStack {
			Text("Hello, World!")
			Button{
				navigation.open(.analysis(id: "123"), from: .library)
			} label: {
				Text("4wrefsdc")
			}
		}

    }
}
