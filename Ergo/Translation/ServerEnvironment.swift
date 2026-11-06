//
//  ServerEnvironment.swift
//  Ergo
//
//  Created by Adon Omeri on 5/11/2026.
//

import Defaults
import Foundation

/// Which Ergo server this install talks to. Only debug builds can choose; release builds always use production.
enum ServerEnvironment: String, CaseIterable, Codable, Defaults.Serializable {
	case production
	/// `ErgoServer` running on Adon's Mac, at the address in `translationServer`
	case thisMac

	/// The hosted server, and the only server address written in the app
	static let productionURL = URL(string: "https://ergo-15.235.184.129.sslip.io")!

	/// The server to talk to now. Nil only in a debug build set to This Mac without a usable address.
	static var current: URL? {
		effective(Defaults[.serverEnvironment], macAddress: Defaults[.translationServer])
	}

	/// Release builds ignore both settings, so a stale value from an old debug install can't redirect them
	static func effective(_ environment: ServerEnvironment, macAddress: String) -> URL? {
		#if DEBUG
			environment.server(macAddress: macAddress)
		#else
			productionURL
		#endif
	}

	var name: String {
		switch self {
			case .production:
				"Production"
			case .thisMac:
				"This Mac"
		}
	}

	func server(macAddress: String) -> URL? {
		switch self {
			case .production:
				Self.productionURL
			case .thisMac:
				Self.macURL(from: macAddress)
		}
	}

	/// A bare host gets `http://`, since `ErgoServer` on a Mac serves plain HTTP. `https://` works too.
	static func macURL(from text: String) -> URL? {
		var text = text.trimmingCharacters(in: .whitespacesAndNewlines)
		guard !text.isEmpty else { return nil }
		if !text.contains("://") {
			text = "http://" + text
		}

		guard
			let url = URL(string: text),
			url.scheme == "https" || url.scheme == "http",
			url.host()?.isEmpty == false
		else {
			return nil
		}
		return url
	}
}
