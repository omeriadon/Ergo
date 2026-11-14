//
//  PhilosopherThumbnail.swift
//  Ergo
//

import SwiftUI

#if os(macOS)
	/// The asset as it is on the Mac, which has no thumbnail preparation for `NSImage`
	struct PhilosopherThumbnail: View {
		let id: String

		var body: some View {
			Image(id)
				.resizable()
				.aspectRatio(contentMode: .fill)
				.frame(width: 40, height: 40)
				.clipShape(Circle())
				.accessibilityHidden(true)
		}
	}
#else
	import UIKit

	struct PhilosopherThumbnail: View {
		let id: String

		@Environment(\.displayScale) private var displayScale
		@State private var preparedImage: UIImage?

		private var taskID: String {
			"\(id)-\(displayScale)"
		}

		var body: some View {
			Group {
				if let preparedImage {
					Image(uiImage: preparedImage)
						.resizable()
						.aspectRatio(contentMode: .fill)
				} else {
					Color.secondary.opacity(0.15)
				}
			}
			.frame(width: 40, height: 40)
			.clipShape(Circle())
			.accessibilityHidden(true)
			.task(id: taskID) {
				// The store caches what it prepares, so a row that scrolls back into view doesn't decode the image again
				guard let image = await PhilosopherThumbnailStore.shared.image(
					for: id,
					displayScale: displayScale
				), !Task.isCancelled else {
					return
				}

				preparedImage = image
			}
			.onChange(of: id) {
				preparedImage = nil
			}
		}
	}

	@MainActor
	private final class PhilosopherThumbnailStore {
		static let shared = PhilosopherThumbnailStore()

		private let cache: NSCache<NSString, UIImage> = {
			let cache = NSCache<NSString, UIImage>()
			cache.totalCostLimit = 2 * 1024 * 1024
			cache.countLimit = 128
			return cache
		}()

		private var inFlight: [String: Task<UIImage?, Never>] = [:]

		func image(for id: String, displayScale: CGFloat) async -> UIImage? {
			let targetPixels = max(1, Int(ceil(40 * displayScale)))
			let key = "\(id)|\(targetPixels)x\(targetPixels)|\(displayScale)"

			if let cached = cache.object(forKey: key as NSString) {
				return cached
			}

			if let existingTask = inFlight[key] {
				return await existingTask.value
			}

			let task = Task.detached(priority: .userInitiated) {
				await PhilosopherThumbnailPreparation.prepare(
					id: id,
					targetPixels: targetPixels
				)
			}
			inFlight[key] = task

			let image = await task.value
			inFlight[key] = nil

			if let image {
				cache.setObject(
					image,
					forKey: key as NSString,
					cost: PhilosopherThumbnailPreparation.byteCost(of: image)
				)
			}

			return image
		}
	}

	private nonisolated enum PhilosopherThumbnailPreparation {
		static func prepare(id: String, targetPixels: Int) async -> UIImage? {
			guard !Task.isCancelled, let source = UIImage(named: id) else {
				return nil
			}

			let requestedSize = requestedSize(
				sourceSize: source.size,
				sourceScale: source.scale,
				targetPixels: targetPixels
			)

			return await source.byPreparingThumbnail(ofSize: requestedSize)
		}

		static func requestedSize(sourceSize: CGSize, sourceScale: CGFloat, targetPixels: Int) -> CGSize {
			let sourcePixels = CGSize(
				width: max(1, sourceSize.width * sourceScale),
				height: max(1, sourceSize.height * sourceScale)
			)
			let shortEdge = min(sourcePixels.width, sourcePixels.height)
			let scale = min(1, CGFloat(targetPixels) / shortEdge)
			let requestedPixels = CGSize(
				width: max(1, ceil(sourcePixels.width * scale)),
				height: max(1, ceil(sourcePixels.height * scale))
			)
			return CGSize(
				width: requestedPixels.width / sourceScale,
				height: requestedPixels.height / sourceScale
			)
		}

		static func byteCost(of image: UIImage) -> Int {
			guard let cgImage = image.cgImage else {
				return 1
			}

			return max(1, cgImage.bytesPerRow * cgImage.height)
		}
	}
#endif
