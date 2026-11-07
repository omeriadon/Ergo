//
//  PageReader.swift
//  Ergo
//
//  Created by Adon Omeri on 7/11/2026.
//

import ErgoProtocol
import ErgoShare
import Foundation

/// Fetches a shared link and finds the text in it (`WebPageText`). This happens on the device: the server only sees what
/// the person goes on to send it.
enum PageReader {
	/// A page's text is nowhere near this, the rest would be scripts and data
	private static let characterLimit = 5 << 20

	private static let session = URLSession(configuration: .ephemeral)

	/// Some sites turn away anything that doesn't look like a browser
	private static let userAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1 Ergo/1.0"

	/// Failures are `ServiceError`s worded for showing. A page with nothing to read is one of them.
	static func read(_ url: URL) async throws -> WebPageText {
		var request = URLRequest(url: secure(url), timeoutInterval: 20)
		request.setValue(userAgent, forHTTPHeaderField: "User-Agent")

		let (data, response): (Data, URLResponse)
		do {
			(data, response) = try await session.data(for: request)
		} catch {
			throw failure(error.localizedDescription)
		}

		if let http = response as? HTTPURLResponse, !(200 ..< 300).contains(http.statusCode) {
			throw failure("Expected a page from \(url.host() ?? "this site"), found status \(http.statusCode)")
		}

		let type = response.mimeType ?? "text/html"
		guard type.hasPrefix("text/") || type.contains("html") else {
			throw failure("Expected a web page, found \(type)")
		}

		let decoded = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1) ?? ""
		let source = String(decoded.prefix(characterLimit))
		let page = type == "text/plain"
			? WebPageText(html: "<p>\(source)</p>")
			: WebPageText(html: source)

		guard !page.text.isEmpty else {
			throw failure("Expected text on this page, found none. It may only show in a browser.")
		}
		return page
	}

	/// App Transport Security blocks plain http, and almost everything answers on https anyway
	private static func secure(_ url: URL) -> URL {
		guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false), components.scheme?.lowercased() == "http" else {
			return url
		}
		components.scheme = "https"
		return components.url ?? url
	}

	private static func failure(_ message: String) -> ServiceError {
		ServiceError(code: .invalidRequest, message: message)
	}
}
