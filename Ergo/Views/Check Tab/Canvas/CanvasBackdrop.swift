//
//  CanvasBackdrop.swift
//  Ergo
//
//  Created by Adon Omeri on 6/11/2026.
//

import SwiftUI

/// The dither behind the Check tab. It is the navigation container's background, so it holds still while a box
/// zooms into its editor instead of being scaled with the canvas it sits behind.
struct CanvasBackdrop: View {
	var body: some View {
		DitherView(configuration: detailViewConf)
			.ignoresSafeArea()
			.allowsHitTesting(false)
	}
}
