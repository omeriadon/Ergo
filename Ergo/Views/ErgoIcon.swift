//
//  ErgoIcon.swift
//  Ergo
//
//  Created by Adon Omeri on 1/11/2026.
//

import SwiftUI

struct ErgoIcon: View {
	var size: CGFloat = 92

	private let diameter: CGFloat = 19.7656

	var body: some View {
		ZStack {
			glassCircle
				.position(x: 46, y: 26.5039)

			glassCircle
				.position(x: 26.2344, y: 63.7891)

			glassCircle
				.position(x: 65.8555, y: 63.7891)
		}
		.frame(width: 92, height: 92)
		.scaleEffect(size / 92)
		.frame(width: size, height: size)
	}

	private var glassCircle: some View {
		Text(" ")
			.frame(width: diameter, height: diameter)
			.glassEffect(.clear.tint(.accent).interactive(), in: Circle())
	}
}
