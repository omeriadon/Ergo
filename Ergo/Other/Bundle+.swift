//
//  Bundle+.swift
//  Ergo
//
//  Created by Adon Omeri on 1/11/2026.
//

import Foundation

extension Bundle {
	/// Returns the marketing version (e.g., "1.0.0")
	var appVersion: String {
		infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
	}

	/// Returns the build number (e.g., "42")
	var buildNumber: String {
		infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
	}
}
