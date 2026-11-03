import CoreGraphics

// Run in the context of PhilosopherThumbnail.swift.
import Foundation

let landscape = PhilosopherThumbnailPreparation.requestedSize(
	sourceSize: CGSize(width: 768, height: 384),
	sourceScale: 1,
	targetPixels: 120
)
precondition(landscape == CGSize(width: 240, height: 120))
let portrait = PhilosopherThumbnailPreparation.requestedSize(
	sourceSize: CGSize(width: 384, height: 768),
	sourceScale: 1,
	targetPixels: 120
)
precondition(portrait == CGSize(width: 120, height: 240))
let retina = PhilosopherThumbnailPreparation.requestedSize(
	sourceSize: CGSize(width: 384, height: 192),
	sourceScale: 2,
	targetPixels: 120
)
precondition(retina == CGSize(width: 120, height: 60))
let small = PhilosopherThumbnailPreparation.requestedSize(
	sourceSize: CGSize(width: 20, height: 30),
	sourceScale: 1,
	targetPixels: 120
)
precondition(small == CGSize(width: 20, height: 30))
print("Thumbnail sizing checks passed: landscape, portrait, display scale, and small source images.")
