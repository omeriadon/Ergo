//
//  ShareViewController.swift
//  ErgoShareExtension
//
//  Created by Adon Omeri on 7/11/2026.
//

import ErgoShare
import SwiftUI
import UIKit
import UniformTypeIdentifiers

/// The system needs a view controller to start from. This one holds `ShareChooserView`, and does the three things only it
/// can: read what was shared, open the app, and tell the system it's finished.
final class ShareViewController: UIViewController {
	private static let ergoURL = URL(string: "ergo://share")!

	override func viewDidLoad() {
		super.viewDidLoad()

		let chooser = ShareChooserView(
			load: { [unowned self] in await sharedContent() },
			openErgo: { [unowned self] in await openErgo() },
			finish: { [unowned self] in extensionContext?.completeRequest(returningItems: nil) },
			cancel: { [unowned self] in extensionContext?.cancelRequest(withError: CocoaError(.userCancelled)) }
		)

		let host = UIHostingController(rootView: chooser)
		addChild(host)
		host.view.frame = view.bounds
		host.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
		view.addSubview(host.view)
		host.didMove(toParent: self)
	}

	private func sharedContent() async -> SharedItem.Content? {
		let items = extensionContext?.inputItems as? [NSExtensionItem] ?? []
		let providers = items.flatMap { $0.attachments ?? [] }

		var url: URL?
		var text: String?
		for provider in providers {
			if url == nil, provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
				url = try? await provider.loadItem(forTypeIdentifier: UTType.url.identifier) as? URL
			} else if text == nil, provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
				let item = try? await provider.loadItem(forTypeIdentifier: UTType.plainText.identifier)
				text = item as? String ?? (item as? Data).map { String(decoding: $0, as: UTF8.self) }
			}
		}
		return SharedItem.Content(url: url, text: text)
	}

	/// Apple only lets Today and iMessage extensions open their app through `extensionContext`. Walking up to the
	/// `UIApplication` object is the way share extensions get to theirs, and it's not a promise: when it stops working this
	/// returns false, the item's still in the inbox, and `ShareChooserView` says to open Ergo by hand.
	private func openErgo() async -> Bool {
		var responder: UIResponder? = self
		while let current = responder {
			if let application = current as? UIApplication {
				return await application.open(Self.ergoURL)
			}
			responder = current.next
		}
		return false
	}
}
