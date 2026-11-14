//
//  StatementEditorTransition.swift
//  Ergo
//
//  Created by Adon Omeri on 7/11/2026.
//

#if os(iOS)
	import SwiftUI
	import UIKit

	/// Opens the statement editor out of its box, and closes it back in, in a narrow window (a wide one uses
	/// `StatementEditorCard`). This is UIKit because the box is hosted on its own,
	/// out of reach of SwiftUI's zoom, which needs a source view it can find. Here the source is simply the box's own view.
	///
	/// `statementID` is the only thing that opens or closes the editor. A hosted editor has its own SwiftUI environment, so
	/// anything it needs from the app's has to be passed in `editor`.
	struct StatementEditorPresenter: UIViewControllerRepresentable {
		let statementID: Statement.ID?
		let canvasBoard: CanvasBoardController
		let editor: (Statement.ID) -> AnyView

		/// The editor has finished closing, and the canvas is what's on screen again
		let closed: () -> Void

		func makeUIViewController(context _: Context) -> StatementEditorPresenterController {
			StatementEditorPresenterController()
		}

		func updateUIViewController(_ controller: StatementEditorPresenterController, context _: Context) {
			controller.canvasBoard = canvasBoard
			controller.editor = editor
			controller.closed = closed
			controller.show(statementID)
		}

		static func dismantleUIViewController(_ controller: StatementEditorPresenterController, coordinator _: Coordinator) {
			controller.closeWithoutAnimation()
		}
	}

	/// An invisible view controller on the canvas, which is what UIKit needs to present from
	final class StatementEditorPresenterController: UIViewController, UIViewControllerTransitioningDelegate {
		var canvasBoard: CanvasBoardController?
		var editor: ((Statement.ID) -> AnyView)?
		var closed: () -> Void = {}

		private var wanted: Statement.ID?
		private var shown: (id: Statement.ID, host: UIViewController)?

		/// UIKit ignores a presentation asked for during another, so a change that comes in during one waits for it to end
		private var isMoving = false

		override func viewDidLoad() {
			super.viewDidLoad()
			view.backgroundColor = .clear
			view.isUserInteractionEnabled = false
		}

		func show(_ id: Statement.ID?) {
			guard id != wanted else { return }
			wanted = id

			// This comes in during a SwiftUI update, which is no time to present anything
			Task {
				settle()
			}
		}

		func closeWithoutAnimation() {
			wanted = nil
			shown?.host.dismiss(animated: false)
			shown = nil
		}

		private func settle() {
			guard !isMoving, wanted != shown?.id else { return }

			if let shown {
				isMoving = true
				shown.host.dismiss(animated: true) { [weak self] in
					guard let self else { return }
					self.shown = nil
					isMoving = false
					closed()
					settle()
				}
			} else if let wanted, let editor {
				// Held in a plain view controller, since the animator masks the presented view and a hosting view can't take one
				let hosted = UIHostingController(rootView: editor(wanted))
				let host = UIViewController()
				host.addChild(hosted)
				hosted.view.frame = host.view.bounds
				hosted.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
				host.view.addSubview(hosted.view)
				hosted.didMove(toParent: host)
				host.modalPresentationStyle = .overFullScreen
				host.transitioningDelegate = self
				shown = (wanted, host)
				isMoving = true
				present(host, animated: true) { [weak self] in
					self?.isMoving = false
					self?.settle()
				}
			}
		}

		func animationController(
			forPresented _: UIViewController,
			presenting _: UIViewController,
			source _: UIViewController
		) -> (any UIViewControllerAnimatedTransitioning)? {
			StatementEditorAnimator(box: shownBox, isOpening: true)
		}

		func animationController(forDismissed _: UIViewController) -> (any UIViewControllerAnimatedTransitioning)? {
			StatementEditorAnimator(box: shownBox, isOpening: false)
		}

		/// Looked up each way, since the box can be gone by the time the editor closes (deleted on another device)
		private var shownBox: UIView? {
			shown.flatMap { canvasBoard?.box($0.id) }
		}
	}

	/// The editor grows out of the box and shrinks back into it, with a picture of the box fading over the top.
	///
	/// The editor is uncovered by a growing mask rather than being scaled. A scaled view leaves the safe area part way through,
	/// and its navigation bar would jump when it arrived.
	private final class StatementEditorAnimator: NSObject, UIViewControllerAnimatedTransitioning {
		private let box: UIView?
		private let isOpening: Bool

		init(box: UIView?, isOpening: Bool) {
			self.box = box
			self.isOpening = isOpening
		}

		private var duration: TimeInterval {
			isOpening ? 0.42 : 0.36
		}

		func transitionDuration(using _: (any UIViewControllerContextTransitioning)?) -> TimeInterval {
			duration
		}

		func animateTransition(using context: any UIViewControllerContextTransitioning) {
			guard let controller = context.viewController(forKey: isOpening ? .to : .from), let editor = controller.view else {
				context.completeTransition(false)
				return
			}

			if isOpening {
				editor.frame = context.finalFrame(for: controller)
				context.containerView.addSubview(editor)
				// Laid out at its real size now, so what's inside it doesn't animate from nothing
				editor.layoutIfNeeded()
			} else {
				editor.endEditing(true)
			}

			let finish = { [isOpening] in
				if !isOpening {
					editor.removeFromSuperview()
				}
				context.completeTransition(!context.transitionWasCancelled)
			}

			if let box, unsafe !UIAccessibility.isReduceMotionEnabled {
				zoom(editor, box: box, in: context.containerView, finish: finish)
			} else {
				fade(editor, finish: finish)
			}
		}

		private func zoom(_ editor: UIView, box: UIView, in container: UIView, finish: @escaping () -> Void) {
			let boxFrame = box.convert(box.bounds, to: container)
			let boxScale = boxFrame.width / box.bounds.width
			let editorScale = container.bounds.width / box.bounds.width

			let mask = UIView()
			mask.backgroundColor = .black
			mask.layer.cornerCurve = .continuous
			editor.mask = mask

			let picture = box.snapshotView(afterScreenUpdates: false) ?? UIView()
			container.addSubview(picture)
			box.alpha = 0

			let atBox = {
				mask.frame = boxFrame
				mask.layer.cornerRadius = StatementBoxView.corner * boxScale
				picture.center = CGPoint(x: boxFrame.midX, y: boxFrame.midY)
				picture.transform = CGAffineTransform(scaleX: boxScale, y: boxScale)
			}
			let atEditor = {
				mask.frame = container.bounds
				mask.layer.cornerRadius = 0
				picture.center = CGPoint(x: container.bounds.midX, y: container.bounds.midY)
				picture.transform = CGAffineTransform(scaleX: editorScale, y: editorScale)
			}
			let showsEditor = { (shown: Bool) in
				editor.alpha = shown ? 1 : 0
				picture.alpha = shown ? 0 : 1
			}

			UIView.performWithoutAnimation {
				isOpening ? atBox() : atEditor()
				showsEditor(!isOpening)
			}

			// A damping ratio of 1 doesn't overshoot, which would show the canvas around the edge of the screen
			let move = UIViewPropertyAnimator(duration: duration, dampingRatio: 1) { [isOpening] in
				isOpening ? atEditor() : atBox()
			}
			move.addCompletion { _ in
				editor.mask = nil
				picture.removeFromSuperview()
				box.alpha = 1
				finish()
			}
			move.startAnimation()

			// Over quickly, at the end where the editor is box-sized
			let crossfade = UIViewPropertyAnimator(duration: duration * 0.4, curve: .easeOut) { [isOpening] in
				showsEditor(isOpening)
			}
			crossfade.startAnimation(afterDelay: isOpening ? 0 : duration * 0.6)
		}

		/// All that's left when there's no box to go to, or under Reduce Motion
		private func fade(_ editor: UIView, finish: @escaping () -> Void) {
			if isOpening {
				editor.alpha = 0
			}
			UIView.animate(withDuration: 0.2) { [isOpening] in
				editor.alpha = isOpening ? 1 : 0
			} completion: { _ in
				finish()
			}
		}
	}
#endif
