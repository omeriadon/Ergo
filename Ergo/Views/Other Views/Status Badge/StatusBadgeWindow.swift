//
//  StatusBadgeWindow.swift
//  Ergo
//
//  Created by Adon Omeri on 10/11/2026.
//

import SwiftUI

#if os(macOS)
	import AppKit

	/// The Mac's counterpart of the iOS window below: a see-through panel that only holds `StatusBadgeOverlay`, laid over the
	/// main window's content, under its toolbar.
	///
	/// It's a window for the same reason as on iOS: a Mac sheet is a window of its own, and a SwiftUI overlay on the root view
	/// is drawn underneath it. The panel is a child of whichever window is main, which carries it along as that window moves.
	/// A sheet becomes key but never main, so main stays the window the sheet hangs from. It floats, so it's above the sheet,
	/// and hides while the app isn't active. It never becomes key and takes no clicks at all, so it can't be swiped away as on
	/// iOS. Nothing is lost by that: every badge goes by itself except progress, which the app ends.
	///
	/// If it ever ends up under a sheet at runtime, ordering it front again when a window becomes key would fix it.
	enum StatusBadgeWindow {
		private static var panel: NSPanel?

		/// The window it's laid over, and what follows that window's size and closing
		private weak static var host: NSWindow?
		private static var observers: [any NSObjectProtocol] = []

		/// Once, at launch. It's attached again every time a window becomes main, whether it's a new one or the same one.
		static func install() {
			guard panel == nil else { return }
			panel = makePanel()

			NotificationCenter.default.addObserver(forName: NSWindow.didBecomeMainNotification, object: nil, queue: .main) { note in
				guard let window = note.object as? NSWindow else { return }
				MainActor.assumeIsolated {
					attach(to: window)
				}
			}
			if let main = NSApplication.shared.mainWindow {
				attach(to: main)
			}
		}

		private static func makePanel() -> NSPanel {
			let panel = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)
			panel.isOpaque = false
			panel.backgroundColor = .clear
			panel.hasShadow = false
			panel.ignoresMouseEvents = true
			panel.hidesOnDeactivate = true
			panel.isReleasedWhenClosed = false
			panel.collectionBehavior = [.fullScreenAuxiliary, .ignoresCycle]

			let content = NSHostingView(rootView: StatusBadgeOverlay().fontDesign(.rounded))
			// The panel follows the window, never the overlay's own size
			content.sizingOptions = []
			panel.contentView = content
			return panel
		}

		private static func attach(to window: NSWindow) {
			// Panels (this one, popovers' and menus' own) are never where badges belong
			// Its actual parent, not `host`: going to the background orders it out, which drops it as a child, and the same
			// window becoming main again on the way back has to take it again
			guard let panel, panel.parent !== window, !(window is NSPanel) else { return }
			detach()
			host = window
			window.addChildWindow(panel, ordered: .above)
			// Becoming a child can take on the parent's level, so it's raised afterwards
			panel.level = .floating
			follow(window)
			panel.orderFront(nil)

			observers = [
				NotificationCenter.default.addObserver(forName: NSWindow.didResizeNotification, object: window, queue: .main) { _ in
					MainActor.assumeIsolated {
						follow(window)
					}
				},
				NotificationCenter.default.addObserver(forName: NSWindow.willCloseNotification, object: window, queue: .main) { _ in
					MainActor.assumeIsolated {
						detach()
					}
				},
			]
		}

		/// The window's content, under the toolbar, which is where a sheet hangs from too
		private static func follow(_ window: NSWindow) {
			panel?.setFrame(window.convertToScreen(window.contentLayoutRect), display: true)
		}

		private static func detach() {
			for observer in observers {
				NotificationCenter.default.removeObserver(observer)
			}
			observers = []
			if let panel {
				host?.removeChildWindow(panel)
				panel.orderOut(nil)
			}
			host = nil
		}
	}
#else
	import UIKit

	/// A second window that sits above the app's own and only holds `StatusBadgeOverlay`.
	///
	/// It's UIKit because a SwiftUI overlay on the root view is drawn underneath any sheet, and most of what fails in Ergo
	/// fails inside one. A window is the only thing above a sheet. It's see-through, and it lets every touch fall to the app
	/// below except the ones that land on the badge itself.
	final class StatusBadgeWindow: UIWindow {
		private static var installed: StatusBadgeWindow?

		/// Once, when the app's scene exists. Never made key, so the keyboard and the app's own window carry on as they were.
		static func install() {
			guard installed == nil,
			      let scene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first
			else { return }

			let host = UIHostingController(rootView: StatusBadgeOverlay().fontDesign(.rounded))
			host.view.backgroundColor = .clear

			let window = StatusBadgeWindow(windowScene: scene)
			window.windowLevel = .alert
			window.backgroundColor = .clear
			window.rootViewController = host
			window.isHidden = false
			installed = window
		}

		override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
			guard StatusBadgeManager.shared.badgeFrame.contains(point) else {
				return nil
			}
			return super.hitTest(point, with: event)
		}
	}
#endif
