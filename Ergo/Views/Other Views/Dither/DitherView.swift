// iOS 17+ / macOS 14+, Swift 6.2+.
// Add this file and OptimizedDither.metal to the same app target.
// Usage: DitherView() or DitherView(configuration: configuration).
// On iPhone, set CADisableMinimumFrameDurationOnPhone = YES in Info.plist to allow ProMotion.
// Use .opacity(...) on DitherView to fade via the compositor without rerendering Metal.
import Defaults
import Foundation
import Metal
import MetalKit
import MetalPerformanceShaders
import QuartzCore
import simd
import SwiftUI
#if os(iOS)
	import UIKit
#elseif os(macOS)
	import AppKit
#endif

public nonisolated struct DitherConfiguration: Equatable, Sendable {
	static let defaultWaveDirection: Float = 135
	static let supportedPaletteCount = 8

	public var waveSpeed: Float = 0.05
	public var waveDirection: Float = Self.defaultWaveDirection
	public var waveFrequency: Float = 3
	public var waveAmplitude: Float = 0.3
	public var waveColor = SIMD3<Float>(0.12, 0.85, 1)
	public var backgroundColor = SIMD3<Float>(0.02, 0.01, 0.08)
	public var colorNum: Float = 4
	public var pixelSize: Float = 5
	public var disableAnimation = false
	public var framesPerSecond = 5
	public var ditherMode = 0
	public var ditherStrength: Float = 1
	public var palette: [SIMD3<Float>] = [
		SIMD3<Float>(0.12, 0.85, 1),
		SIMD3<Float>(0.55, 0.18, 1),
		SIMD3<Float>(1, 0.2, 0.55),
		SIMD3<Float>(1, 0.72, 0.18),
	]
	public var scale: Float = 1
	public var contrast: Float = 1
	public var brightness: Float = 0
	public var intro = true
	public var transparent = false
	public var gap: Float = 0
	public var cornerRadius: Float = 0
	public var joinAdjacentSquares = false
	public var backgroundStyle = "custom"
	public var colorPlacement = "squares"
	public var squareStyle = "white"
	public var useThemeColors = false
	public var opacity: Float = 1
	public var topBlur = false
	public var clipsToDeviceCorners = true

	public var cursorInteractionEnabled = false
	public var cursorRadius: Double = 0.5
	public var cursorStrength: Double = 1
	public var cursorResponse: Double = 0.28
	public var cursorTrailDuration: Double = 0.7
	public var cursorFadeDuration: Double = 0.8
	public var cursorWarp: Double = 0.15

	public init() {}

	static func normalizedWaveDirection(_ degrees: Float) -> Float? {
		guard degrees.isFinite else { return nil }
		let normalized = degrees.truncatingRemainder(dividingBy: 360)
		let positive = normalized >= 0 ? normalized : normalized + 360
		let snapped = (positive / 45).rounded() * 45
		return snapped >= 360 ? 0 : snapped
	}

	static func waveDirectionVector(for degrees: Float) -> SIMD2<Float> {
		let normalized = normalizedWaveDirection(degrees) ?? defaultWaveDirection
		let radians = normalized * .pi / 180
		return SIMD2<Float>(sin(radians), -cos(radians)) * sqrt(2)
	}

	static func compassDirection(for degrees: Float) -> String {
		let normalized = normalizedWaveDirection(degrees) ?? defaultWaveDirection
		return ["N", "NE", "E", "SE", "S", "SW", "W", "NW"][Int((normalized / 45).rounded()) % 8]
	}

	func bounded() -> Self {
		var value = self
		value.waveSpeed = finite(waveSpeed, 0.05, 0 ... 1)
		value.framesPerSecond = min(max(framesPerSecond, 1), 120)
		value.waveDirection = Self.normalizedWaveDirection(waveDirection) ?? Self.defaultWaveDirection
		value.waveFrequency = finite(waveFrequency, 3, 0.01 ... 12)
		value.waveAmplitude = finite(waveAmplitude, 0.3, 0 ... 1)
		value.colorNum = finite(colorNum, 4, 2 ... 16)
		value.pixelSize = finite(pixelSize, 2, 1 ... 4096)
		value.ditherStrength = finite(ditherStrength, 1, 0 ... 1)
		value.scale = finite(scale, 1, 0.05 ... 32)
		value.contrast = finite(contrast, 1, 0.01 ... 8)
		value.brightness = finite(brightness, 0, -1 ... 1)
		value.gap = finite(gap, 0, 0 ... 0.45)
		value.cornerRadius = finite(cornerRadius, 0, 0 ... 0.5)
		value.opacity = finite(opacity, 1, 0 ... 1)
		value.waveColor = finiteColor(waveColor, .init(repeating: 0.5))
		value.backgroundColor = finiteColor(backgroundColor, .zero)
		value.palette = palette.prefix(Self.supportedPaletteCount).map { finiteColor($0, .init(repeating: 0.5)) }
		value.ditherMode = min(max(ditherMode, 0), 7)
		value.backgroundStyle = Self.validBackgroundStyle(backgroundStyle)
		value.colorPlacement = Self.validColorPlacement(colorPlacement)
		value.squareStyle = Self.validSquareStyle(squareStyle)
		value.cursorRadius = safe(cursorRadius, 0.05 ... 2, fallback: 0.5)
		value.cursorStrength = safe(cursorStrength, -2 ... 2, fallback: 1)
		value.cursorResponse = safe(cursorResponse, 0.05 ... 1, fallback: 0.28)
		value.cursorTrailDuration = safe(cursorTrailDuration, 0 ... 2, fallback: 0.7)
		value.cursorFadeDuration = safe(cursorFadeDuration, 0.1 ... 3, fallback: 0.8)
		value.cursorWarp = safe(cursorWarp, 0 ... 1, fallback: 0.15)
		return value
	}

	static func validBackgroundStyle(_ value: String?) -> String {
		switch value {
			case "custom", "black", "white", "dim": value!
			default: "custom"
		}
	}

	static func validColorPlacement(_ value: String?) -> String {
		value == "background" ? "background" : "squares"
	}

	static func validSquareStyle(_ value: String?) -> String {
		value == "black" ? "black" : "white"
	}

	func safe(_ value: Double, _ range: ClosedRange<Double>, fallback: Double = 0) -> Double {
		min(max(value.isFinite ? value : fallback, range.lowerBound), range.upperBound)
	}

	private func finite(_ value: Float, _ fallback: Float, _ range: ClosedRange<Float>) -> Float {
		min(max(value.isFinite ? value : fallback, range.lowerBound), range.upperBound)
	}

	private func finiteColor(_ value: SIMD3<Float>, _ fallback: SIMD3<Float>) -> SIMD3<Float> {
		SIMD3<Float>(finite(value.x, fallback.x, 0 ... 1), finite(value.y, fallback.y, 0 ... 1), finite(value.z, fallback.z, 0 ... 1))
	}
}

struct DitherAnimationTiming {
	private var lastTime: TimeInterval?

	mutating func advance(now: TimeInterval, isAdvancing: Bool) -> TimeInterval {
		guard let previous = lastTime else {
			lastTime = now
			return 0
		}

		guard isAdvancing else {
			return 0
		}

		lastTime = now
		return max(0, now - previous)
	}

	mutating func seed(now: TimeInterval) {
		lastTime = now
	}

	mutating func reset() {
		lastTime = nil
	}
}

struct DitherFrameScheduler {
	private(set) var lastRenderTime: TimeInterval?
	private var frameRequested = true

	mutating func requestFrame() {
		frameRequested = true
	}

	func shouldRender(now: TimeInterval, isAnimating: Bool, framesPerSecond: Int = 5) -> Bool {
		guard isAnimating || frameRequested else {
			return false
		}

		guard isAnimating else {
			return true
		}

		let interval = 1.0 / Double(max(1, framesPerSecond))
		guard let lastRenderTime else {
			return true
		}
		return now - lastRenderTime >= interval
	}

	mutating func didRender(now: TimeInterval) {
		lastRenderTime = now
		frameRequested = false
	}
}

struct DitherRenderInputs: Equatable, Sendable {
	var themePositions: [SIMD2<Float>] = []
	var themeColors: [SIMD3<Float>] = []
	var cursorTrail: [SIMD3<Float>] = []
	var cursorTouch: SIMD2<Float> = .zero
	var cursorPresence: Float = 0
	var screenOrigin: SIMD2<Float> = .zero
	var screenSize: SIMD2<Float> = .zero
	var screenCornerRadius: Float = 0

	static let empty = DitherRenderInputs()
}

private struct FieldUniforms {
	var resolution: SIMD2<Float>
	var cell: Float
	var time: Float
	var waveSpeed: Float
	var waveDirection: SIMD2<Float>
	var waveFrequency: Float
	var waveAmplitude: Float
	var scale: Float
	var contrast: Float
	var brightness: Float
	var intro: Float
	var reach: Float
	var cursorPosition: SIMD2<Float>
	var cursorRadius: Float
	var cursorStrength: Float
	var cursorWarp: Float
	var cursorPresence: Float
	var cursorTouch: SIMD2<Float>
	var trail0: SIMD3<Float>
	var trail1: SIMD3<Float>
	var trail2: SIMD3<Float>
	var trail3: SIMD3<Float>
	var trail4: SIMD3<Float>
	var trail5: SIMD3<Float>
	var trail6: SIMD3<Float>
	var trail7: SIMD3<Float>
}

private struct DitherUniforms {
	var fieldSize: SIMD2<Int32>
	var cellDevice: Float
	var mode: Int32
	var colorNum: Float
	var ditherStrength: Float
	var wave: SIMD3<Float>
	var background: SIMD3<Float>
	var paletteCount: Int32
	var transparent: Float
	var gap: Float
	var cornerRadius: Float
	var joinAdjacentSquares: Int32
	var viewportSize: SIMD2<Int32>
	var themeCount: Int32
	var useThemeColors: Int32
	var colorPlacement: Int32
	var backgroundStyle: Int32
	var squareStyle: Int32
	var cursorPresence: Float
	var screenOrigin: SIMD2<Float>
	var screenSize: SIMD2<Float>
	var screenCornerRadius: Float
}

private struct TopBlurUniforms {
	var stripHeight: Float
}

private struct CellBlurUniforms {
	var width: Int32
	var cellSize: Int32
	var sourceRows: Int32
	var radius: Int32
	var cellRadius: Int32
	var phaseCount: Int32
	var weightStride: Int32
}

private struct CellBlurCompositeUniforms {
	var stripHeight: Int32
	var cellSize: Int32
	var rowCount: Int32
	var width: Int32
	var transparent: Float
	var scale: Float
	var background: SIMD3<Float>
}

private final class DitherMetalBundleMarker {}

private struct CoverageKey: Hashable {
	let cell: Int
	let gap: Float
	let radius: Float
}

@MainActor
private final class SharedMetalResources {
	let device: MTLDevice
	let queue: MTLCommandQueue
	let library: MTLLibrary
	let vertex: MTLFunction
	let gradientTexture: MTLTexture
	private var fieldPipeline: MTLRenderPipelineState?
	private var cellPipeline: MTLRenderPipelineState?
	private var fusedCellComputePipeline: MTLComputePipelineState?
	private var referenceDitherPipeline: MTLRenderPipelineState?
	private var optimizedDitherPipeline: MTLRenderPipelineState?
	private var atlasDitherPipeline: MTLRenderPipelineState?
	private var coverageComputePipeline: MTLComputePipelineState?
	private var joinMaskComputePipeline: MTLComputePipelineState?
	private var blurCompositePipeline: MTLRenderPipelineState?
	private var cellBlurHorizontalPipeline: MTLComputePipelineState?
	private var cellBlurCompositePipeline: MTLRenderPipelineState?
	private var coverageTextures: [CoverageKey: MTLTexture] = [:]

	init() throws {
		guard let device = MTLCreateSystemDefaultDevice() else {
			throw NSError(domain: "DitherMetal", code: 1, userInfo: [NSLocalizedDescriptionKey: "Metal device is unavailable"])
		}
		self.device = device

		guard let library = try? device.makeDefaultLibrary(bundle: Bundle(for: DitherMetalBundleMarker.self)) else {
			throw NSError(domain: "DitherMetal", code: 3, userInfo: [NSLocalizedDescriptionKey: "default.metallib could not be loaded; include OptimizedDither.metal in this target"])
		}
		guard let vertex = library.makeFunction(name: "ditherVertex"),
		      let gradientFunction = library.makeFunction(name: "ditherGradient"),
		      let queue = device.makeCommandQueue(),
		      let gradients = device.makeTexture(descriptor: {
		      	let descriptor = MTLTextureDescriptor.texture2DDescriptor(
		      		pixelFormat: .rgba32Float,
		      		width: 289,
		      		height: 289,
		      		mipmapped: false
		      	)
		      	descriptor.storageMode = .private
		      	descriptor.usage = [.renderTarget, .shaderRead]
		      	return descriptor
		      }()),
		      let initialization = queue.makeCommandBuffer()
		else {
			throw NSError(domain: "DitherMetal", code: 4, userInfo: [NSLocalizedDescriptionKey: "Dither shader functions are missing"])
		}
		self.queue = queue
		self.library = library
		self.vertex = vertex
		gradientTexture = gradients

		func makePipeline(fragment: MTLFunction, pixelFormat: MTLPixelFormat) throws -> MTLRenderPipelineState {
			let descriptor = MTLRenderPipelineDescriptor()
			descriptor.vertexFunction = vertex
			descriptor.fragmentFunction = fragment
			descriptor.colorAttachments[0].pixelFormat = pixelFormat
			return try device.makeRenderPipelineState(descriptor: descriptor)
		}

		let gradientPipeline = try makePipeline(fragment: gradientFunction, pixelFormat: .rgba32Float)
		let gradientPass = MTLRenderPassDescriptor()
		gradientPass.colorAttachments[0].texture = gradients
		gradientPass.colorAttachments[0].loadAction = .dontCare
		gradientPass.colorAttachments[0].storeAction = .store
		guard let encoder = initialization.makeRenderCommandEncoder(descriptor: gradientPass) else {
			throw NSError(domain: "DitherMetal", code: 13)
		}
		encoder.setRenderPipelineState(gradientPipeline)
		encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
		encoder.endEncoding()
		initialization.commit()
		initialization.waitUntilCompleted()
		if let error = initialization.error {
			throw error
		}
	}

	private func renderPipeline(fragment name: String, pixelFormat: MTLPixelFormat) throws -> MTLRenderPipelineState {
		guard let function = library.makeFunction(name: name) else {
			throw NSError(domain: "DitherMetal", code: 4, userInfo: [NSLocalizedDescriptionKey: "Missing Metal shader function: \(name)"])
		}
		let descriptor = MTLRenderPipelineDescriptor()
		descriptor.vertexFunction = vertex
		descriptor.fragmentFunction = function
		descriptor.colorAttachments[0].pixelFormat = pixelFormat
		do {
			return try device.makeRenderPipelineState(descriptor: descriptor)
		} catch {
			throw NSError(domain: "DitherMetal", code: 5, userInfo: [NSLocalizedDescriptionKey: "Dither pipeline creation failed: \(error)"])
		}
	}

	func fieldPipelineState() throws -> MTLRenderPipelineState {
		if let fieldPipeline {
			return fieldPipeline
		}
		let pipeline = try renderPipeline(fragment: "ditherField", pixelFormat: .rgba8Unorm)
		fieldPipeline = pipeline
		return pipeline
	}

	func cellPipelineState() throws -> MTLRenderPipelineState {
		if let cellPipeline {
			return cellPipeline
		}
		let pipeline = try renderPipeline(fragment: "ditherCell", pixelFormat: .rgba16Float)
		cellPipeline = pipeline
		return pipeline
	}

	func fusedCellComputePipelineState() throws -> MTLComputePipelineState {
		if let fusedCellComputePipeline {
			return fusedCellComputePipeline
		}
		guard let function = library.makeFunction(name: "ditherFusedCellCompute") else {
			throw NSError(domain: "DitherMetal", code: 4)
		}
		let pipeline = try device.makeComputePipelineState(function: function)
		fusedCellComputePipeline = pipeline
		return pipeline
	}

	func ditherPipelineState(fused: Bool) throws -> MTLRenderPipelineState {
		if fused, let optimizedDitherPipeline {
			return optimizedDitherPipeline
		}
		if !fused, let referenceDitherPipeline {
			return referenceDitherPipeline
		}
		let pipeline = try renderPipeline(fragment: fused ? "ditherUpscaleOptimized" : "ditherUpscale", pixelFormat: .bgra8Unorm)
		if fused {
			optimizedDitherPipeline = pipeline
		} else {
			referenceDitherPipeline = pipeline
		}
		return pipeline
	}

	func atlasDitherPipelineState() throws -> MTLRenderPipelineState {
		if let atlasDitherPipeline {
			return atlasDitherPipeline
		}
		let pipeline = try renderPipeline(fragment: "ditherUpscaleAtlas", pixelFormat: .bgra8Unorm)
		atlasDitherPipeline = pipeline
		return pipeline
	}

	func coverageComputePipelineState() throws -> MTLComputePipelineState {
		if let coverageComputePipeline {
			return coverageComputePipeline
		}
		guard let function = library.makeFunction(name: "ditherCoverageCompute") else {
			throw NSError(domain: "DitherMetal", code: 4)
		}
		let pipeline = try device.makeComputePipelineState(function: function)
		coverageComputePipeline = pipeline
		return pipeline
	}

	func joinMaskComputePipelineState() throws -> MTLComputePipelineState {
		if let joinMaskComputePipeline {
			return joinMaskComputePipeline
		}
		guard let function = library.makeFunction(name: "ditherJoinMaskCompute") else {
			throw NSError(domain: "DitherMetal", code: 4)
		}
		let pipeline = try device.makeComputePipelineState(function: function)
		joinMaskComputePipeline = pipeline
		return pipeline
	}

	func blurCompositePipelineState() throws -> MTLRenderPipelineState {
		if let blurCompositePipeline {
			return blurCompositePipeline
		}
		let pipeline = try renderPipeline(fragment: "ditherTopBlurComposite", pixelFormat: .bgra8Unorm)
		blurCompositePipeline = pipeline
		return pipeline
	}

	func cellBlurHorizontalPipelineState() throws -> MTLComputePipelineState {
		if let cellBlurHorizontalPipeline {
			return cellBlurHorizontalPipeline
		}
		guard let function = library.makeFunction(name: "ditherCellBlurHorizontal") else {
			throw NSError(domain: "DitherMetal", code: 4)
		}
		let pipeline = try device.makeComputePipelineState(function: function)
		cellBlurHorizontalPipeline = pipeline
		return pipeline
	}

	func cellBlurCompositePipelineState() throws -> MTLRenderPipelineState {
		if let cellBlurCompositePipeline {
			return cellBlurCompositePipeline
		}
		let pipeline = try renderPipeline(fragment: "ditherCellBlurComposite", pixelFormat: .bgra8Unorm)
		cellBlurCompositePipeline = pipeline
		return pipeline
	}

	func coverageTexture(for key: CoverageKey) -> MTLTexture? {
		coverageTextures[key]
	}

	func publishCoverageTexture(_ texture: MTLTexture, for key: CoverageKey) {
		if coverageTextures.count >= 8 {
			coverageTextures.removeAll(keepingCapacity: true)
		}
		coverageTextures[key] = texture
	}
}

@MainActor
private final class DitherMetalRenderer {
	static let topBlurStripPoints: Float = 104
	nonisolated static let topBlurMaximumSigma: Float = 5
	static let topBlurGaussianSigmas: [Float] = [
		topBlurMaximumSigma * 0.1,
		topBlurMaximumSigma * 0.4,
		topBlurMaximumSigma,
	]
	static let topBlurDecayCoefficient: Float = 3

	struct RenderMetrics {
		let cpuElapsed: TimeInterval
		let gpuElapsed: TimeInterval?
		let renderPassCount: Int
		let computeDispatchCount: Int
		let gaussianEncodeCount: Int
	}

	let device: MTLDevice
	private let queue: MTLCommandQueue
	private let sharedResources: SharedMetalResources
	private let gradientTexture: MTLTexture
	private var fieldTexture: MTLTexture?
	private var cellTexture: MTLTexture?
	private var joinMaskTexture: MTLTexture?
	private let finalPassDescriptor = MTLRenderPassDescriptor()
	private let blurSourcePassDescriptor = MTLRenderPassDescriptor()
	private var fieldSize = MTLSize(width: 1, height: 1, depth: 1)
	private var time: Float = 0
	private var reveal: Float = 0
	private var animationTiming = DitherAnimationTiming()
	private var paletteBuffer: MTLBuffer
	private var themePositions = [SIMD2<Float>](repeating: .zero, count: 8)
	private var themeColors = [SIMD3<Float>](repeating: .zero, count: 8)
	private var lastPalette: [SIMD3<Float>] = []
	private(set) var lastRenderMetrics: RenderMetrics?
	private let usesFusedFieldAndCellPass: Bool
	private let usesTopBlur: Bool
	private let blurScale: Float
	private let usesTwoDimensionalThreadgroups: Bool
	private let usesCellBlurFastPath: Bool
	private var topBlurResources: TopBlurResources?
	private var cellBlurResources: CellBlurResources?

	private struct TopBlurResources {
		let source: MTLTexture
		let levels: [MTLTexture]
		let kernels: [MPSImageGaussianBlur]
		let scale: Float
	}

	private struct CellBlurResources {
		let levels: [MTLTexture]
		let horizontalWeights: [MTLBuffer]
		let verticalWeights: [MTLBuffer]
		let profile: MTLBuffer
		let rowCount: Int
		let scale: Float
		let cell: Int
		let width: Int
		let stripHeight: Int
	}

	/// Swift serializes static initialization. Immutable Metal objects are shared;
	/// failed initialization remains a thrown error rather than terminating the app.
	private static let sharedResources = Result { try SharedMetalResources() }

	private let usesCoverageAtlas: Bool

	init(
		usesFusedFieldAndCellPass: Bool = true,
		usesCoverageAtlas: Bool = true,
		usesTopBlur: Bool = true,
		blurScale: Float = 1,
		usesTwoDimensionalThreadgroups: Bool = true,
		usesCellBlurFastPath: Bool = true
	) throws {
		self.usesCoverageAtlas = usesCoverageAtlas
		self.usesFusedFieldAndCellPass = usesFusedFieldAndCellPass
		self.usesTopBlur = usesTopBlur
		self.blurScale = max(0.01, blurScale)
		self.usesTwoDimensionalThreadgroups = usesTwoDimensionalThreadgroups
		self.usesCellBlurFastPath = usesCellBlurFastPath
		guard MemoryLayout<FieldUniforms>.stride == 224,
		      MemoryLayout<DitherUniforms>.stride == 144
		else {
			throw NSError(domain: "DitherMetal", code: 12, userInfo: [NSLocalizedDescriptionKey: "Swift and Metal uniform layouts do not match"])
		}
		let resources = try Self.sharedResources.get()
		sharedResources = resources
		device = resources.device
		queue = resources.queue
		gradientTexture = resources.gradientTexture
		guard let paletteBuffer = device.makeBuffer(length: 8 * MemoryLayout<SIMD3<Float>>.stride, options: .storageModeShared) else {
			throw NSError(domain: "DitherMetal", code: 11, userInfo: [NSLocalizedDescriptionKey: "Could not allocate palette buffer"])
		}
		self.paletteBuffer = paletteBuffer
	}

	func render(to drawable: CAMetalDrawable, size: CGSize, configuration: DitherConfiguration, advance: Bool) throws {
		try render(to: drawable, size: size, configuration: configuration, inputs: .empty, advance: advance)
	}

	func render(to drawable: CAMetalDrawable, size: CGSize, configuration: DitherConfiguration, inputs: DitherRenderInputs, advance: Bool) throws {
		let drawableWidth = drawable.texture.width
		let drawableHeight = drawable.texture.height
		let ratio = Float(drawableWidth) / max(Float(size.width), 1)
		let cell = max(1, Int(configuration.pixelSize * ratio))
		try render(to: drawable.texture, width: drawableWidth, height: drawableHeight, cell: cell, configuration: configuration, inputs: inputs, advance: advance, drawable: drawable, waitUntilCompleted: false, scale: ratio)
	}

	func render(to target: MTLTexture, width: Int, height: Int, cell: Int, configuration: DitherConfiguration, advance: Bool = true, atTime: Float? = nil) throws {
		try render(to: target, width: width, height: height, cell: cell, configuration: configuration, inputs: .empty, advance: advance, atTime: atTime, drawable: nil, waitUntilCompleted: true, scale: blurScale)
	}

	func render(to target: MTLTexture, width: Int, height: Int, cell: Int, configuration: DitherConfiguration, inputs: DitherRenderInputs, advance: Bool = true, atTime: Float? = nil) throws {
		try render(to: target, width: width, height: height, cell: cell, configuration: configuration, inputs: inputs, advance: advance, atTime: atTime, drawable: nil, waitUntilCompleted: true, scale: blurScale)
	}

	func render(to target: MTLTexture, width: Int, height: Int, cell: Int, configuration: DitherConfiguration, scale: Float, advance: Bool = true, atTime: Float? = nil) throws {
		try render(to: target, width: width, height: height, cell: cell, configuration: configuration, inputs: .empty, advance: advance, atTime: atTime, drawable: nil, waitUntilCompleted: true, scale: scale)
	}

	func resetAnimationTiming() {
		animationTiming.reset()
	}

	func seedAnimationTiming() {
		animationTiming.seed(now: CACurrentMediaTime())
	}

	var isIntroComplete: Bool {
		reveal >= 1
	}

	var sharedGradientResourceIdentifier: ObjectIdentifier {
		ObjectIdentifier(gradientTexture)
	}

	static func topBlurSigma(at fraction: Float, maxSigma: Float = topBlurMaximumSigma) -> Float {
		let t = min(1, max(0, fraction))
		return max(0, maxSigma * exp(-topBlurDecayCoefficient * t) * pow(1 - t, 2))
	}

	static func topBlurStripPixels(scale: Float) -> Int {
		max(1, Int((topBlurStripPoints * max(0.01, scale)).rounded(.up)))
	}

	func restartIntro() {
		reveal = 0
	}

	private func render(to target: MTLTexture, width: Int, height: Int, cell: Int, configuration: DitherConfiguration, inputs: DitherRenderInputs, advance: Bool, atTime: Float? = nil, drawable: CAMetalDrawable?, waitUntilCompleted: Bool, scale: Float) throws {
		let cpuStart = CACurrentMediaTime()
		let delta = Float(animationTiming.advance(now: cpuStart, isAdvancing: advance))
		if advance && !configuration.disableAnimation && atTime == nil {
			time += delta
		}
		if let atTime {
			time = atTime
		}
		if configuration.intro {
			reveal = min(1, reveal + delta / 1.8)
		} else {
			reveal = 1
		}
		guard width > 0, height > 0, width <= 16384, height <= 16384 else {
			throw NSError(domain: "DitherMetal", code: 6, userInfo: [NSLocalizedDescriptionKey: "Dither drawable size is outside supported bounds"])
		}
		let cell = max(1, min(cell, width, height))
		let columns = max(1, width / cell)
		let rows = max(1, height / cell)
		if cellTexture == nil || fieldSize.width != columns || fieldSize.height != rows {
			if !usesFusedFieldAndCellPass {
				let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba8Unorm, width: columns, height: rows, mipmapped: false)
				descriptor.usage = [.renderTarget, .shaderRead]
				descriptor.storageMode = .private
				fieldTexture = device.makeTexture(descriptor: descriptor)
			}
			let cellDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba16Float, width: columns, height: rows, mipmapped: false)
			cellDescriptor.usage = usesFusedFieldAndCellPass ? [.shaderRead, .shaderWrite] : [.renderTarget, .shaderRead]
			cellDescriptor.storageMode = .private
			cellTexture = device.makeTexture(descriptor: cellDescriptor)
			joinMaskTexture = nil
			fieldSize = MTLSize(width: columns, height: rows, depth: 1)
		}
		guard let cellTexture else {
			throw NSError(domain: "DitherMetal", code: 6, userInfo: [NSLocalizedDescriptionKey: "Could not allocate field texture"])
		}
		func trailSample(_ index: Int) -> SIMD3<Float> {
			guard configuration.cursorInteractionEnabled,
			      !configuration.disableAnimation,
			      index < inputs.cursorTrail.count
			else {
				return .zero
			}
			let sample = inputs.cursorTrail[index]
			return SIMD3<Float>(sample.x * scale, sample.y * scale, sample.z)
		}
		var field = FieldUniforms(
			resolution: SIMD2<Float>(Float(columns * cell), Float(rows * cell)),
			cell: Float(cell),
			time: time,
			waveSpeed: max(0, configuration.waveSpeed),
			waveDirection: DitherConfiguration.waveDirectionVector(for: configuration.waveDirection),
			waveFrequency: configuration.waveFrequency,
			waveAmplitude: configuration.waveAmplitude,
			scale: max(0.05, configuration.scale),
			contrast: configuration.contrast,
			brightness: configuration.brightness,
			intro: reveal,
			reach: 1.5,
			cursorPosition: inputs.cursorTrail.first.map { SIMD2<Float>($0.x, $0.y) } ?? .zero,
			cursorRadius: Float(configuration.cursorRadius),
			cursorStrength: Float(configuration.cursorStrength),
			cursorWarp: Float(configuration.cursorWarp),
			cursorPresence: configuration.cursorInteractionEnabled && !configuration.disableAnimation ? inputs.cursorPresence : 0,
			cursorTouch: inputs.cursorTouch * scale,
			trail0: trailSample(0),
			trail1: trailSample(1),
			trail2: trailSample(2),
			trail3: trailSample(3),
			trail4: trailSample(4),
			trail5: trailSample(5),
			trail6: trailSample(6),
			trail7: trailSample(7)
		)
		let effectiveBackground: SIMD3<Float> = switch configuration.backgroundStyle {
			case "black": .zero
			case "white": SIMD3<Float>(repeating: 1)
			case "dim": configuration.waveColor * 0.2
			default: configuration.backgroundColor
		}
		let effectiveWave: SIMD3<Float> = configuration.colorPlacement == "background"
			? (configuration.squareStyle == "black" ? .zero : SIMD3<Float>(repeating: 1))
			: configuration.waveColor
		let backgroundStyle: Int32 = switch configuration.backgroundStyle {
			case "black": 1
			case "white": 2
			case "dim": 3
			default: 0
		}
		var dither = DitherUniforms(
			fieldSize: SIMD2<Int32>(Int32(columns), Int32(rows)),
			cellDevice: Float(cell),
			mode: Int32(configuration.ditherMode),
			colorNum: max(2, configuration.colorNum),
			ditherStrength: min(1, max(0, configuration.ditherStrength)),
			wave: effectiveWave,
			background: configuration.colorPlacement == "background" ? configuration.waveColor : effectiveBackground,
			paletteCount: configuration.colorPlacement == "background"
				? 0
				: Int32(min(DitherConfiguration.supportedPaletteCount, configuration.useThemeColors ? inputs.themeColors.count : configuration.palette.count)),
			transparent: configuration.transparent ? 1 : 0,
			gap: min(0.45, max(0, configuration.gap)),
			cornerRadius: min(0.5, max(0, configuration.cornerRadius)),
			joinAdjacentSquares: configuration.joinAdjacentSquares ? 1 : 0,
			viewportSize: SIMD2<Int32>(Int32(width), Int32(height)),
			themeCount: Int32(min(DitherConfiguration.supportedPaletteCount, inputs.themeColors.count)),
			useThemeColors: configuration.useThemeColors ? 1 : 0,
			colorPlacement: configuration.colorPlacement == "background" ? 1 : 0,
			backgroundStyle: backgroundStyle,
			squareStyle: configuration.squareStyle == "black" ? 1 : 0,
			cursorPresence: inputs.cursorPresence,
			screenOrigin: inputs.screenOrigin * scale,
			screenSize: inputs.screenSize * scale,
			screenCornerRadius: configuration.clipsToDeviceCorners ? inputs.screenCornerRadius * scale : 0
		)
		for index in 0 ..< 8 {
			themePositions[index] = index < inputs.themePositions.count ? inputs.themePositions[index] : .zero
			themeColors[index] = index < inputs.themeColors.count ? inputs.themeColors[index] : .zero
		}
		let palette = configuration.useThemeColors ? inputs.themeColors : configuration.palette
		if palette != lastPalette {
			var paletteData = [SIMD3<Float>](repeating: SIMD3<Float>(), count: DitherConfiguration.supportedPaletteCount)
			for (index, color) in palette.prefix(DitherConfiguration.supportedPaletteCount).enumerated() {
				paletteData[index] = color
			}
			guard let replacement = paletteData.withUnsafeBytes({ bytes in
				guard let baseAddress = bytes.baseAddress else {
					return nil as MTLBuffer?
				}
				return unsafe device.makeBuffer(bytes: baseAddress, length: bytes.count, options: .storageModeShared)
			}) else {
				throw NSError(domain: "DitherMetal", code: 11, userInfo: [NSLocalizedDescriptionKey: "Could not allocate palette buffer"])
			}
			paletteBuffer = replacement
			lastPalette = palette
		}
		guard let commandBuffer = queue.makeCommandBuffer() else {
			throw NSError(domain: "DitherMetal", code: 7, userInfo: [NSLocalizedDescriptionKey: "Could not create Metal command buffer"])
		}
		var renderPassCount = 0
		var computeDispatchCount = 0
		var gaussianEncodeCount = 0
		var fusedComputeEncoder: MTLComputeCommandEncoder?
		defer {
			fusedComputeEncoder?.endEncoding()
		}
		if usesFusedFieldAndCellPass {
			guard let computeEncoder = commandBuffer.makeComputeCommandEncoder() else {
				throw NSError(domain: "DitherMetal", code: 8, userInfo: [NSLocalizedDescriptionKey: "Could not create fused field and cell compute encoder"])
			}
			fusedComputeEncoder = computeEncoder
			let pipeline = try sharedResources.fusedCellComputePipelineState()
			computeEncoder.setComputePipelineState(pipeline)
			computeEncoder.setTexture(cellTexture, index: 0)
			computeEncoder.setTexture(gradientTexture, index: 1)
			unsafe computeEncoder.setBytes(&field, length: MemoryLayout<FieldUniforms>.stride, index: 0)
			unsafe computeEncoder.setBytes(&dither, length: MemoryLayout<DitherUniforms>.stride, index: 1)
			computeEncoder.setBuffer(paletteBuffer, offset: 0, index: 2)
			themePositions.withUnsafeBytes { bytes in
				unsafe computeEncoder.setBytes(bytes.baseAddress!, length: bytes.count, index: 3)
			}
			themeColors.withUnsafeBytes { bytes in
				unsafe computeEncoder.setBytes(bytes.baseAddress!, length: bytes.count, index: 4)
			}
			dispatch(
				computeEncoder,
				width: columns,
				height: rows,
				pipeline: pipeline,
				usesTwoDimensionalThreadgroups: usesTwoDimensionalThreadgroups
			)
			computeDispatchCount += 1
		} else {
			guard let fieldTexture else {
				throw NSError(domain: "DitherMetal", code: 6, userInfo: [NSLocalizedDescriptionKey: "Could not allocate field texture"])
			}
			let fieldPass = MTLRenderPassDescriptor()
			fieldPass.colorAttachments[0].texture = fieldTexture
			fieldPass.colorAttachments[0].loadAction = .dontCare
			fieldPass.colorAttachments[0].storeAction = .store
			let fieldPipeline = try sharedResources.fieldPipelineState()
			guard let fieldEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: fieldPass) else {
				throw NSError(domain: "DitherMetal", code: 8, userInfo: [NSLocalizedDescriptionKey: "Could not create field encoder"])
			}
			fieldEncoder.setRenderPipelineState(fieldPipeline)
			unsafe fieldEncoder.setFragmentBytes(&field, length: MemoryLayout<FieldUniforms>.stride, index: 0)
			fieldEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
			fieldEncoder.endEncoding()
			renderPassCount += 1
			let cellPass = MTLRenderPassDescriptor()
			cellPass.colorAttachments[0].texture = cellTexture
			cellPass.colorAttachments[0].loadAction = .dontCare
			cellPass.colorAttachments[0].storeAction = .store
			let cellPipeline = try sharedResources.cellPipelineState()
			guard let cellEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: cellPass) else {
				throw NSError(domain: "DitherMetal", code: 8, userInfo: [NSLocalizedDescriptionKey: "Could not create cell encoder"])
			}
			cellEncoder.setRenderPipelineState(cellPipeline)
			cellEncoder.setFragmentTexture(fieldTexture, index: 0)
			unsafe cellEncoder.setFragmentBytes(&dither, length: MemoryLayout<DitherUniforms>.stride, index: 0)
			cellEncoder.setFragmentBuffer(paletteBuffer, offset: 0, index: 1)
			themePositions.withUnsafeBytes { bytes in
				unsafe cellEncoder.setFragmentBytes(bytes.baseAddress!, length: bytes.count, index: 2)
			}
			themeColors.withUnsafeBytes { bytes in
				unsafe cellEncoder.setFragmentBytes(bytes.baseAddress!, length: bytes.count, index: 3)
			}
			cellEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
			cellEncoder.endEncoding()
			renderPassCount += 1
		}
		var coverageTexture: MTLTexture?
		var newCoverageKey: CoverageKey?
		if usesFusedFieldAndCellPass && usesCoverageAtlas && cell <= 128 && (dither.gap > 0 || dither.cornerRadius > 0) {
			let key = CoverageKey(cell: cell, gap: dither.gap, radius: dither.cornerRadius)
			if let cached = sharedResources.coverageTexture(for: key) {
				coverageTexture = cached
			} else {
				let resources = try Self.sharedResources.get()
				let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .r32Float, width: cell, height: cell * (dither.gap > 0 ? 1 : 16), mipmapped: false)
				descriptor.storageMode = .private
				descriptor.usage = [.shaderRead, .shaderWrite]
				guard let texture = device.makeTexture(descriptor: descriptor), let computeEncoder = fusedComputeEncoder else {
					throw NSError(domain: "DitherMetal", code: 14)
				}
				let pipeline = try resources.coverageComputePipelineState()
				computeEncoder.setComputePipelineState(pipeline)
				computeEncoder.setTexture(texture, index: 0)
				unsafe computeEncoder.setBytes(&dither, length: MemoryLayout<DitherUniforms>.stride, index: 0)
				dispatch(
					computeEncoder,
					width: cell,
					height: texture.height,
					pipeline: pipeline
				)
				computeDispatchCount += 1
				newCoverageKey = key
				coverageTexture = texture
			}
		}
		if coverageTexture != nil && dither.joinAdjacentSquares > 0 && dither.gap == 0 && dither.cornerRadius > 0 {
			if joinMaskTexture == nil {
				let maskDescriptor = MTLTextureDescriptor.texture2DDescriptor(
					pixelFormat: .r8Uint,
					width: columns,
					height: rows,
					mipmapped: false
				)
				maskDescriptor.storageMode = .private
				maskDescriptor.usage = [.shaderRead, .shaderWrite]
				joinMaskTexture = device.makeTexture(descriptor: maskDescriptor)
			}
			guard let joinMaskTexture, let encoder = fusedComputeEncoder else {
				throw NSError(domain: "DitherMetal", code: 15)
			}
			let resources = try Self.sharedResources.get()
			encoder.memoryBarrier(scope: .textures)
			let pipeline = try resources.joinMaskComputePipelineState()
			encoder.setComputePipelineState(pipeline)
			encoder.setTexture(cellTexture, index: 0)
			encoder.setTexture(joinMaskTexture, index: 1)
			unsafe encoder.setBytes(&dither, length: MemoryLayout<DitherUniforms>.stride, index: 0)
			dispatch(
				encoder,
				width: columns,
				height: rows,
				pipeline: pipeline,
				usesTwoDimensionalThreadgroups: usesTwoDimensionalThreadgroups
			)
			computeDispatchCount += 1
		}
		fusedComputeEncoder?.endEncoding()
		fusedComputeEncoder = nil
		let usesCellBlur = usesTopBlur && usesCellBlurFastPath && canUseCellBlurFastPath(
			width: width,
			height: height,
			cell: cell,
			configuration: configuration,
			scale: scale
		)
		if usesTopBlur {
			if usesCellBlur {
				try encodeCellBlur(
					commandBuffer: commandBuffer,
					width: width,
					height: height,
					cell: cell,
					scale: scale,
					dither: dither
				)
			} else {
				try encodeTopBlur(
					commandBuffer: commandBuffer,
					width: width,
					height: height,
					scale: scale,
					dither: dither,
					coverageTexture: coverageTexture,
					joinMaskTexture: joinMaskTexture,
					paletteBuffer: paletteBuffer
				)
			}
			if usesCellBlur {
				computeDispatchCount += Self.topBlurGaussianSigmas.count
			} else {
				renderPassCount += 1
				gaussianEncodeCount = Self.topBlurGaussianSigmas.count
			}
		}
		let finalPass = finalPassDescriptor
		finalPass.colorAttachments[0].texture = target
		defer {
			finalPass.colorAttachments[0].texture = nil
		}
		finalPass.colorAttachments[0].loadAction = usesFusedFieldAndCellPass ? .dontCare : .clear
		finalPass.colorAttachments[0].storeAction = .store
		finalPass.colorAttachments[0].clearColor = MTLClearColor(red: Double(effectiveBackground.x), green: Double(effectiveBackground.y), blue: Double(effectiveBackground.z), alpha: 1)
		guard let finalEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: finalPass) else {
			throw NSError(domain: "DitherMetal", code: 9, userInfo: [NSLocalizedDescriptionKey: "Could not create composite encoder"])
		}
		var finalEncodingEnded = false
		defer {
			if !finalEncodingEnded {
				finalEncoder.endEncoding()
			}
		}
		renderPassCount += 1
		if let coverageTexture {
			try finalEncoder.setRenderPipelineState(sharedResources.atlasDitherPipelineState())
			finalEncoder.setFragmentTexture(coverageTexture, index: 1)
			finalEncoder.setFragmentTexture(joinMaskTexture, index: 2)
		} else {
			try finalEncoder.setRenderPipelineState(sharedResources.ditherPipelineState(fused: usesFusedFieldAndCellPass))
		}
		finalEncoder.setFragmentTexture(cellTexture, index: 0)
		unsafe finalEncoder.setFragmentBytes(&dither, length: MemoryLayout<DitherUniforms>.stride, index: 0)
		finalEncoder.setFragmentBuffer(paletteBuffer, offset: 0, index: 1)
		themePositions.withUnsafeBytes { bytes in
			unsafe finalEncoder.setFragmentBytes(bytes.baseAddress!, length: bytes.count, index: 2)
		}
		themeColors.withUnsafeBytes { bytes in
			unsafe finalEncoder.setFragmentBytes(bytes.baseAddress!, length: bytes.count, index: 3)
		}
		let stripHeight = usesTopBlur ? min(height, Self.topBlurStripPixels(scale: scale)) : 0
		if stripHeight < height {
			finalEncoder.setScissorRect(MTLScissorRect(x: 0, y: stripHeight, width: width, height: height - stripHeight))
			finalEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
		}
		if usesCellBlur {
			try encodeCellBlurComposite(encoder: finalEncoder, width: width, stripHeight: stripHeight, cell: cell, dither: dither)
		} else if usesTopBlur {
			try encodeTopBlurComposite(encoder: finalEncoder, width: width, stripHeight: stripHeight, scale: scale)
		}
		finalEncoder.endEncoding()
		finalEncodingEnded = true
		if let drawable {
			commandBuffer.present(drawable)
		}
		commandBuffer.commit()
		// Publish only after submission: a failed encoder must not leave an
		// uninitialized atlas in the cache for the next frame.
		if let newCoverageKey, let coverageTexture {
			sharedResources.publishCoverageTexture(coverageTexture, for: newCoverageKey)
		}
		let submissionElapsed = CACurrentMediaTime() - cpuStart
		if waitUntilCompleted {
			commandBuffer.waitUntilCompleted()
			if let error = commandBuffer.error {
				throw error
			}
			let gpuElapsed = commandBuffer.gpuStartTime > 0 && commandBuffer.gpuEndTime > commandBuffer.gpuStartTime
				? commandBuffer.gpuEndTime - commandBuffer.gpuStartTime
				: nil
			lastRenderMetrics = RenderMetrics(
				cpuElapsed: submissionElapsed,
				gpuElapsed: gpuElapsed,
				renderPassCount: renderPassCount,
				computeDispatchCount: computeDispatchCount,
				gaussianEncodeCount: gaussianEncodeCount
			)
		}
	}

	private func dispatch(
		_ encoder: MTLComputeCommandEncoder,
		width: Int,
		height: Int,
		pipeline: MTLComputePipelineState,
		usesTwoDimensionalThreadgroups: Bool = false
	) {
		let threadgroupWidth = min(pipeline.threadExecutionWidth, width)
		let threadgroupHeight: Int = if usesTwoDimensionalThreadgroups {
			min(
				8,
				pipeline.maxTotalThreadsPerThreadgroup / threadgroupWidth,
				height
			)
		} else {
			1
		}

		let threads = MTLSize(
			width: threadgroupWidth,
			height: threadgroupHeight,
			depth: 1
		)
		let groups = MTLSize(
			width: (width + threadgroupWidth - 1) / threadgroupWidth,
			height: (height + threadgroupHeight - 1) / threadgroupHeight,
			depth: 1
		)
		encoder.dispatchThreadgroups(groups, threadsPerThreadgroup: threads)
	}

	private func encodeTopBlur(
		commandBuffer: MTLCommandBuffer,
		width: Int,
		height: Int,
		scale: Float,
		dither: DitherUniforms,
		coverageTexture: MTLTexture?,
		joinMaskTexture: MTLTexture?,
		paletteBuffer: MTLBuffer
	) throws {
		let stripHeight = min(height, Self.topBlurStripPixels(scale: scale))
		let maxSigma = Self.topBlurMaximumSigma * max(0.01, scale)
		let padding = max(1, Int(ceil(maxSigma * 3)))
		let sourceHeight = min(height, stripHeight + padding)
		let scaleChanged = topBlurResources?.scale != scale
		if topBlurResources == nil || topBlurResources?.source.width != width || topBlurResources?.source.height != sourceHeight || scaleChanged {
			let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm, width: width, height: sourceHeight, mipmapped: false)
			descriptor.storageMode = .private
			descriptor.usage = [.renderTarget, .shaderRead]
			guard let source = device.makeTexture(descriptor: descriptor) else {
				throw NSError(domain: "DitherMetal", code: 16, userInfo: [NSLocalizedDescriptionKey: "Could not allocate top blur source"])
			}
			// Each level is sampled only while sigma exceeds the previous level.
			// Crop destination height instead of blurring every level across the strip.
			let sigmas = Self.topBlurGaussianSigmas
			descriptor.pixelFormat = .rgba16Float
			var levels: [MTLTexture] = []
			for index in sigmas.indices {
				let minimumSigma: Float = index == 0 ? 0 : sigmas[index - 1]
				var contributingRows = stripHeight
				while contributingRows > 1, Self.topBlurSigma(at: Float(contributingRows - 1) / Float(Self.topBlurStripPixels(scale: scale))) <= minimumSigma {
					contributingRows -= 1
				}
				// Bilinear sampling needs the row just beyond the last contribution.
				descriptor.height = min(sourceHeight, contributingRows + 1)
				guard let level = device.makeTexture(descriptor: descriptor) else {
					throw NSError(domain: "DitherMetal", code: 16, userInfo: [NSLocalizedDescriptionKey: "Could not allocate top blur level"])
				}
				levels.append(level)
			}
			topBlurResources = TopBlurResources(
				source: source,
				levels: levels,
				kernels: sigmas.map {
					let kernel = MPSImageGaussianBlur(device: device, sigma: $0 * max(0.01, scale))
					kernel.edgeMode = .clamp
					return kernel
				},
				scale: scale
			)
		}
		guard let resources = topBlurResources else {
			return
		}
		var sourceDither = dither
		let sourcePass = blurSourcePassDescriptor
		sourcePass.colorAttachments[0].texture = resources.source
		sourcePass.colorAttachments[0].loadAction = .dontCare
		sourcePass.colorAttachments[0].storeAction = .store
		let sourcePipeline = try coverageTexture == nil
			? sharedResources.ditherPipelineState(fused: usesFusedFieldAndCellPass)
			: sharedResources.atlasDitherPipelineState()
		guard let sourceEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: sourcePass) else {
			throw NSError(domain: "DitherMetal", code: 17, userInfo: [NSLocalizedDescriptionKey: "Could not create top blur source encoder"])
		}
		sourceEncoder.setRenderPipelineState(sourcePipeline)
		sourceEncoder.setFragmentTexture(cellTexture, index: 0)
		if let coverageTexture {
			sourceEncoder.setFragmentTexture(coverageTexture, index: 1)
			sourceEncoder.setFragmentTexture(joinMaskTexture, index: 2)
		}
		unsafe sourceEncoder.setFragmentBytes(&sourceDither, length: MemoryLayout<DitherUniforms>.stride, index: 0)
		sourceEncoder.setFragmentBuffer(paletteBuffer, offset: 0, index: 1)
		themePositions.withUnsafeBytes { bytes in
			unsafe sourceEncoder.setFragmentBytes(bytes.baseAddress!, length: bytes.count, index: 2)
		}
		themeColors.withUnsafeBytes { bytes in
			unsafe sourceEncoder.setFragmentBytes(bytes.baseAddress!, length: bytes.count, index: 3)
		}
		sourceEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
		sourceEncoder.endEncoding()
		for (kernel, level) in zip(resources.kernels, resources.levels) {
			kernel.encode(commandBuffer: commandBuffer, sourceTexture: resources.source, destinationTexture: level)
		}
	}

	private func canUseCellBlurFastPath(
		width: Int,
		height: Int,
		cell: Int,
		configuration: DitherConfiguration,
		scale: Float
	) -> Bool {
		guard usesFusedFieldAndCellPass,
		      cell >= 4,
		      cell <= 128,
		      scale == 1 || scale == 2,
		      configuration.gap == 0,
		      configuration.cornerRadius == 0,
		      width.isMultiple(of: cell),
		      height.isMultiple(of: cell)
		else {
			return false
		}
		let stripHeight = Self.topBlurStripPixels(scale: scale)
		let halo = Int(ceil(Self.topBlurMaximumSigma * max(0.01, scale) * 3))
		return height >= stripHeight + halo
	}

	private func encodeCellBlur(
		commandBuffer: MTLCommandBuffer,
		width: Int,
		height: Int,
		cell: Int,
		scale: Float,
		dither: DitherUniforms
	) throws {
		let stripHeight = min(height, Self.topBlurStripPixels(scale: scale))
		let sigmas = Self.topBlurGaussianSigmas.map { $0 * max(0.01, scale) }
		let radii = sigmas.map { Int(ceil($0 * 3)) }
		let rowCount = min(height / cell, Int(ceil(Double(stripHeight + radii[2]) / Double(cell))) + 1)
		let keyChanged = cellBlurResources == nil
			|| cellBlurResources?.width != width
			|| cellBlurResources?.cell != cell
			|| cellBlurResources?.scale != scale
			|| cellBlurResources?.stripHeight != stripHeight
			|| cellBlurResources?.rowCount != rowCount
		if keyChanged {
			var levels: [MTLTexture] = []
			var horizontalWeights: [MTLBuffer] = []
			var verticalWeights: [MTLBuffer] = []
			for level in sigmas.indices {
				let descriptor = MTLTextureDescriptor.texture2DDescriptor(
					pixelFormat: .rgba16Float,
					width: width,
					height: rowCount,
					mipmapped: false
				)
				descriptor.storageMode = .private
				descriptor.usage = [.shaderRead, .shaderWrite]
				guard let texture = device.makeTexture(descriptor: descriptor) else {
					throw NSError(domain: "DitherMetal", code: 18, userInfo: [NSLocalizedDescriptionKey: "Could not allocate cell blur level"])
				}
				levels.append(texture)
				let cellRadius = Int(ceil(Double(radii[level]) / Double(cell))) + 1
				let pixelWeights = try gaussianWeights(sigma: sigmas[level], radius: radii[level])
				let horizontal = cellIntervalWeights(
					sigma: sigmas[level],
					radius: radii[level],
					cell: cell,
					cellRadius: cellRadius,
					pixelWeights: pixelWeights
				)
				guard let horizontalBuffer = horizontal.withUnsafeBytes({ bytes in
					unsafe device.makeBuffer(bytes: bytes.baseAddress!, length: bytes.count, options: .storageModeShared)
				}) else {
					throw NSError(domain: "DitherMetal", code: 18, userInfo: [NSLocalizedDescriptionKey: "Could not allocate cell blur weights"])
				}
				horizontalWeights.append(horizontalBuffer)
				var vertical = [Float](repeating: 0, count: stripHeight * rowCount)
				for y in 0 ..< stripHeight {
					var total: Float = 0
					for offset in -radii[level] ... radii[level] {
						let sample = min(height - 1, max(0, y + offset))
						let row = sample / cell
						let weight = pixelWeights[offset + radii[level]]
						vertical[y * rowCount + row] += weight
						total += weight
					}
					if total > 0 {
						for row in 0 ..< rowCount {
							vertical[y * rowCount + row] /= total
						}
					}
				}
				guard let verticalBuffer = vertical.withUnsafeBytes({ bytes in
					unsafe device.makeBuffer(bytes: bytes.baseAddress!, length: bytes.count, options: .storageModeShared)
				}) else {
					throw NSError(domain: "DitherMetal", code: 18, userInfo: [NSLocalizedDescriptionKey: "Could not allocate cell blur vertical weights"])
				}
				verticalWeights.append(verticalBuffer)
			}
			let profile = (0 ..< stripHeight).map { y in
				Self.topBlurSigma(at: (Float(y) + 0.5) / Float(Self.topBlurStripPixels(scale: scale)))
			}
			guard let profileBuffer = profile.withUnsafeBytes({ bytes in
				unsafe device.makeBuffer(bytes: bytes.baseAddress!, length: bytes.count, options: .storageModeShared)
			}) else {
				throw NSError(domain: "DitherMetal", code: 18, userInfo: [NSLocalizedDescriptionKey: "Could not allocate cell blur profile"])
			}
			cellBlurResources = CellBlurResources(
				levels: levels,
				horizontalWeights: horizontalWeights,
				verticalWeights: verticalWeights,
				profile: profileBuffer,
				rowCount: rowCount,
				scale: scale,
				cell: cell,
				width: width,
				stripHeight: stripHeight
			)
		}
		let horizontalPipeline = try sharedResources.cellBlurHorizontalPipelineState()
		guard let resources = cellBlurResources,
		      let encoder = commandBuffer.makeComputeCommandEncoder()
		else {
			throw NSError(domain: "DitherMetal", code: 18, userInfo: [NSLocalizedDescriptionKey: "Could not create cell blur encoder"])
		}
		var uniforms = CellBlurUniforms(
			width: Int32(width),
			cellSize: Int32(cell),
			sourceRows: Int32(resources.rowCount),
			radius: 0,
			cellRadius: 0,
			phaseCount: Int32(cell),
			weightStride: 0
		)
		var sourceDither = dither
		encoder.setComputePipelineState(horizontalPipeline)
		encoder.setTexture(cellTexture, index: 0)
		unsafe encoder.setBytes(&sourceDither, length: MemoryLayout<DitherUniforms>.stride, index: 0)
		for level in sigmas.indices {
			uniforms.radius = Int32(radii[level])
			uniforms.cellRadius = Int32(ceil(Double(radii[level]) / Double(cell)) + 1)
			uniforms.weightStride = uniforms.cellRadius * 2 + 1
			encoder.setTexture(resources.levels[level], index: 1)
			encoder.setBuffer(resources.horizontalWeights[level], offset: 0, index: 1)
			unsafe encoder.setBytes(&uniforms, length: MemoryLayout<CellBlurUniforms>.stride, index: 2)
			dispatch(
				encoder,
				width: cell == 4 ? width / 4 : width,
				height: resources.rowCount,
				pipeline: horizontalPipeline,
				usesTwoDimensionalThreadgroups: true
			)
		}
		encoder.endEncoding()
	}

	private func encodeCellBlurComposite(encoder: MTLRenderCommandEncoder, width: Int, stripHeight: Int, cell: Int, dither: DitherUniforms) throws {
		guard let resources = cellBlurResources else {
			return
		}
		var uniforms = CellBlurCompositeUniforms(
			stripHeight: Int32(stripHeight),
			cellSize: Int32(cell),
			rowCount: Int32(resources.rowCount),
			width: Int32(width),
			transparent: 0,
			scale: resources.scale,
			background: dither.background
		)
		uniforms.transparent = dither.transparent
		encoder.setViewport(MTLViewport(originX: 0, originY: 0, width: Double(width), height: Double(stripHeight), znear: 0, zfar: 1))
		encoder.setScissorRect(MTLScissorRect(x: 0, y: 0, width: width, height: stripHeight))
		try encoder.setRenderPipelineState(sharedResources.cellBlurCompositePipelineState())
		for index in resources.levels.indices {
			encoder.setFragmentTexture(resources.levels[index], index: index)
			encoder.setFragmentBuffer(resources.verticalWeights[index], offset: 0, index: index)
		}
		encoder.setFragmentTexture(cellTexture, index: 3)
		encoder.setFragmentBuffer(resources.profile, offset: 0, index: 3)
		unsafe encoder.setFragmentBytes(&uniforms, length: MemoryLayout<CellBlurCompositeUniforms>.stride, index: 4)
		encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
	}

	private func gaussianWeights(sigma: Float, radius: Int) throws -> [Float] {
		guard sigma > 0 else {
			return [1]
		}
		// MPS uses a different compact kernel for small radii. Recover it once
		// per resource configuration, outside the recurring render path.
		if sigma <= 2 {
			let side = max(65, radius * 2 + 3)
			let center = side / 2
			let descriptor = MTLTextureDescriptor.texture2DDescriptor(
				pixelFormat: .rgba32Float,
				width: side,
				height: 1,
				mipmapped: false
			)
			descriptor.storageMode = .shared
			descriptor.usage = [.shaderRead, .shaderWrite]
			guard let source = device.makeTexture(descriptor: descriptor),
			      let destination = device.makeTexture(descriptor: descriptor),
			      let command = queue.makeCommandBuffer()
			else {
				throw NSError(domain: "DitherMetal", code: 18)
			}
			var pixels = [Float](repeating: 0, count: side * 4)
			for channel in 0 ..< 4 {
				pixels[center * 4 + channel] = 1
			}
			pixels.withUnsafeBytes {
				unsafe source.replace(region: MTLRegionMake2D(0, 0, side, 1), mipmapLevel: 0, withBytes: $0.baseAddress!, bytesPerRow: side * 16)
			}
			let kernel = MPSImageGaussianBlur(device: device, sigma: sigma)
			kernel.edgeMode = .clamp
			kernel.encode(commandBuffer: command, sourceTexture: source, destinationTexture: destination)
			command.commit()
			command.waitUntilCompleted()
			if let error = command.error {
				throw error
			}
			pixels.withUnsafeMutableBytes {
				unsafe destination.getBytes($0.baseAddress!, bytesPerRow: side * 16, from: MTLRegionMake2D(0, 0, side, 1), mipmapLevel: 0)
			}
			let weights = (-radius ... radius).map { pixels[(center + $0) * 4] }
			let sum = weights.reduce(0, +)
			return weights.map { $0 / sum }
		}
		var weights = (-radius ... radius).map { offset in
			exp(-0.5 * pow(Float(offset) / sigma, 2))
		}
		let sum = weights.reduce(0, +)
		if sum > 0 {
			weights = weights.map { $0 / sum }
		}
		return weights
	}

	private func cellIntervalWeights(sigma _: Float, radius: Int, cell: Int, cellRadius: Int, pixelWeights: [Float]) -> [Float] {
		var result = [Float](repeating: 0, count: cell * (cellRadius * 2 + 1))
		for phase in 0 ..< cell {
			for offset in -radius ... radius {
				let samplePosition = phase + offset
				let cellOffset: Int = if samplePosition >= 0 {
					samplePosition / cell
				} else {
					-(((-samplePosition) + cell - 1) / cell)
				}
				result[phase * (cellRadius * 2 + 1) + cellOffset + cellRadius] += pixelWeights[offset + radius]
			}
		}
		return result
	}

	private func encodeTopBlurComposite(encoder: MTLRenderCommandEncoder, width: Int, stripHeight: Int, scale: Float) throws {
		guard let resources = topBlurResources else {
			return
		}
		var uniforms = TopBlurUniforms(stripHeight: Float(Self.topBlurStripPixels(scale: scale)))
		encoder.setViewport(MTLViewport(originX: 0, originY: 0, width: Double(width), height: Double(stripHeight), znear: 0, zfar: 1))
		encoder.setScissorRect(MTLScissorRect(x: 0, y: 0, width: width, height: stripHeight))
		try encoder.setRenderPipelineState(sharedResources.blurCompositePipelineState())
		encoder.setFragmentTexture(resources.source, index: 0)
		for (index, level) in resources.levels.enumerated() {
			encoder.setFragmentTexture(level, index: index + 1)
		}
		unsafe encoder.setFragmentBytes(&uniforms, length: MemoryLayout<TopBlurUniforms>.stride, index: 0)
		encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
	}
}

/// An interactive Metal background. Size it with SwiftUI layout modifiers.
@MainActor
private final class DitherInputStorage {
	var hoverLocation: CGPoint?
	var dragLocation: CGPoint?

	var location: CGPoint? {
		dragLocation ?? hoverLocation
	}

	func setHoverLocation(_ location: CGPoint?) {
		hoverLocation = location
	}

	func setDragLocation(_ location: CGPoint?) {
		dragLocation = location
	}

	func clear() {
		hoverLocation = nil
		dragLocation = nil
	}
}

@MainActor
public struct DitherView: View {
	public var configuration: DitherConfiguration

	/// Ignores the Dither setting, for places like About where it's the whole point
	public var alwaysEnabled: Bool

	@Default(.ditherEnabled) private var ditherEnabled

	public init(
		configuration: DitherConfiguration = DitherConfiguration(),
		alwaysEnabled: Bool = false
	) {
		self.configuration = configuration
		self.alwaysEnabled = alwaysEnabled
	}

	/// When the setting is off nothing below is created, so no Metal view, layer, or render loop exists at all
	public var body: some View {
		if ditherEnabled || alwaysEnabled {
			DitherContentView(configuration: configuration)
		}
	}
}

@MainActor
private struct DitherContentView: View {
	let configuration: DitherConfiguration

	@State private var inputStorage = DitherInputStorage()
	@State private var isVisible = false

	@Environment(\.scenePhase) private var scenePhase
	@Environment(\.accessibilityReduceMotion) private var reduceMotion

	var body: some View {
		let bounded = configuration.bounded()
		DitherPlatformView(
			configuration: renderingConfiguration(bounded),
			active: scenePhase == .active && isVisible && bounded.opacity > 0,
			reduceMotion: reduceMotion,
			inputStorage: inputStorage
		)
		.opacity(Double(bounded.opacity))
		.contentShape(Rectangle())
		.modifier(DitherInputModifier(
			inputStorage: inputStorage,
			enabled: bounded.cursorInteractionEnabled && !bounded.disableAnimation && !reduceMotion
		))
		.onChange(of: scenePhase) { _, phase in
			if phase != .active {
				inputStorage.clear()
			}
		}
		.onAppear {
			isVisible = true
		}
		.onDisappear {
			isVisible = false
			inputStorage.clear()
		}
		.allowsHitTesting(bounded.cursorInteractionEnabled && !bounded.disableAnimation && !reduceMotion)
		.accessibilityHidden(true)
	}

	private func renderingConfiguration(_ value: DitherConfiguration) -> DitherConfiguration {
		var value = value
		value.opacity = 1
		return value
	}
}

private struct DitherInputModifier: ViewModifier {
	let inputStorage: DitherInputStorage
	let enabled: Bool

	@GestureState private var isDragging = false

	func body(content: Content) -> some View {
		if enabled {
			content
				.onContinuousHover { phase in
					switch phase {
						case let .active(location):
							inputStorage.setHoverLocation(location)
						case .ended:
							inputStorage.setHoverLocation(nil)
					}
				}
				.simultaneousGesture(
					DragGesture(minimumDistance: 0, coordinateSpace: .local)
						.updating($isDragging) { _, isDragging, _ in
							isDragging = true
						}
						.onChanged { value in
							inputStorage.setDragLocation(value.location)
						}
				)
				.onChange(of: isDragging) { _, isDragging in
					if !isDragging {
						inputStorage.setDragLocation(nil)
					}
				}
				.onDisappear {
					inputStorage.clear()
				}
		} else {
			content
		}
	}
}

private struct DitherPlatformView {
	let configuration: DitherConfiguration
	let active: Bool
	let reduceMotion: Bool
	let inputStorage: DitherInputStorage

	@MainActor
	private func update(_ view: DitherHostView) {
		view.update(
			configuration: configuration,
			active: active,
			reduceMotion: reduceMotion,
			inputStorage: inputStorage
		)
	}
}

#if os(iOS)
	extension DitherPlatformView: UIViewRepresentable {
		func makeUIView(context _: Context) -> DitherHostView {
			let view = DitherHostView(frame: .zero, device: MTLCreateSystemDefaultDevice())
			update(view)
			return view
		}

		func updateUIView(_ uiView: DitherHostView, context _: Context) {
			update(uiView)
		}

		static func dismantleUIView(_ uiView: DitherHostView, coordinator _: ()) {
			uiView.isPaused = true
			uiView.delegate = nil
		}
	}
#elseif os(macOS)
	extension DitherPlatformView: NSViewRepresentable {
		func makeNSView(context _: Context) -> DitherHostView {
			let view = DitherHostView(frame: .zero, device: MTLCreateSystemDefaultDevice())
			update(view)
			return view
		}

		func updateNSView(_ nsView: DitherHostView, context _: Context) {
			update(nsView)
		}

		static func dismantleNSView(_ nsView: DitherHostView, coordinator _: ()) {
			nsView.isPaused = true
			nsView.delegate = nil
		}
	}
#endif

@MainActor
private final class DitherHostView: MTKView, MTKViewDelegate {
	private var configuration = DitherConfiguration()
	private var active = false
	private var reduceMotion = false
	private var renderer: DitherMetalRenderer?
	private var failed = false
	private var inputStorage: DitherInputStorage?
	private var interaction = DitherInteraction()
	private var frameScheduler = DitherFrameScheduler()
	#if os(macOS)
		private var occlusionObserver: NSObjectProtocol?
	#else
		/// Empty, fills the window and takes its corners from it. UIKit has no property for the display's radius, but a
		/// view concentric with the window reports it through `effectiveRadius(corner:)`.
		private let cornerProbe: UIView = {
			let probe = UIView()
			probe.isUserInteractionEnabled = false
			probe.autoresizingMask = [.flexibleWidth, .flexibleHeight]
			probe.cornerConfiguration = .corners(radius: .containerConcentric())
			return probe
		}()
	#endif

	override init(frame: CGRect, device: MTLDevice?) {
		super.init(frame: frame, device: device)
		colorPixelFormat = .bgra8Unorm
		framebufferOnly = true
		depthStencilPixelFormat = .invalid
		autoResizeDrawable = true
		isPaused = true
		enableSetNeedsDisplay = true
		#if os(iOS)
			isOpaque = false
			backgroundColor = .clear
		#else
			wantsLayer = true
		#endif
		if let metalLayer = layer as? CAMetalLayer {
			metalLayer.isOpaque = false
			metalLayer.colorspace = CGColorSpace(name: CGColorSpace.sRGB)
		}
		delegate = self
	}

	@available(*, unavailable)
	required init(coder _: NSCoder) {
		fatalError("Use DitherView()")
	}

	func update(
		configuration: DitherConfiguration,
		active: Bool,
		reduceMotion: Bool,
		inputStorage: DitherInputStorage
	) {
		guard self.configuration != configuration || self.active != active || self.reduceMotion != reduceMotion || self.inputStorage !== inputStorage else {
			return
		}
		if self.configuration.topBlur != configuration.topBlur {
			renderer = nil
		}
		self.configuration = configuration
		self.active = active
		self.reduceMotion = reduceMotion
		self.inputStorage = inputStorage

		#if os(iOS)
			isOpaque = !configuration.transparent
			backgroundColor = configuration.transparent ? .clear : .black
		#else
			layer?.isOpaque = !configuration.transparent
		#endif
		if let metalLayer = layer as? CAMetalLayer {
			metalLayer.isOpaque = !configuration.transparent
		}
		failed = false
		updateScheduling()
		requestFrame()
	}

	#if os(iOS)
		override func didMoveToWindow() {
			super.didMoveToWindow()
			cornerProbe.removeFromSuperview()
			if let window {
				cornerProbe.frame = window.bounds
				window.insertSubview(cornerProbe, at: 0)
			}
			updateScheduling()
			requestFrame()
		}
	#else
		override func viewDidMoveToWindow() {
			super.viewDidMoveToWindow()
			updateOcclusionObserver()
			updateScheduling()
			requestFrame()
		}

		override func viewDidChangeBackingProperties() {
			super.viewDidChangeBackingProperties()
			updateScheduling()
			requestFrame()
		}

		override func viewDidHide() {
			super.viewDidHide()
			updateScheduling()
		}

		override func viewDidUnhide() {
			super.viewDidUnhide()
			updateScheduling()
			requestFrame()
		}
	#endif

	#if os(macOS)
		deinit {
			if let occlusionObserver {
				NotificationCenter.default.removeObserver(occlusionObserver)
			}
		}

		private func updateOcclusionObserver() {
			if let occlusionObserver {
				NotificationCenter.default.removeObserver(occlusionObserver)
			}
			occlusionObserver = nil
			guard let window else {
				return
			}
			occlusionObserver = NotificationCenter.default.addObserver(
				forName: NSWindow.didChangeOcclusionStateNotification,
				object: window,
				queue: .main
			) { [weak self] _ in
				guard let self else {
					return
				}
				updateScheduling()
				if canRender {
					requestFrame()
				}
			}
		}
	#endif

	private var canRender: Bool {
		guard window != nil, active else {
			return false
		}
		#if os(iOS)
			return !isHidden
		#else
			return !isHiddenOrHasHiddenAncestor && window?.occlusionState.contains(.visible) == true
		#endif
	}

	private var hasVisibleDrawableArea: Bool {
		#if os(iOS)
			guard let window else {
				return false
			}
			var visible = convert(bounds, to: window).intersection(window.bounds)
			var ancestor = superview
			while let view = ancestor, !visible.isEmpty {
				if view.isHidden || view.alpha == 0 {
					return false
				}
				if view.clipsToBounds {
					visible = visible.intersection(view.convert(view.bounds, to: window))
				}
				ancestor = view.superview
			}
			return !visible.isEmpty && alpha > 0
		#else
			return !visibleRect.isEmpty
		#endif
	}

	private func updateScheduling() {
		preferredFramesPerSecond = configuration.framesPerSecond
		if !canRender || reduceMotion || configuration.disableAnimation || !configuration.cursorInteractionEnabled {
			interaction = DitherInteraction()
		}
		let paused = !canRender || reduceMotion || configuration.disableAnimation || failed
		if isPaused != paused {
			renderer?.seedAnimationTiming()
		}
		isPaused = paused
		enableSetNeedsDisplay = paused
		if !canRender {
			releaseDrawables()
		}
	}

	private func requestFrame() {
		frameScheduler.requestFrame()
		#if os(iOS)
			setNeedsDisplay()
		#else
			needsDisplay = true
		#endif
	}

	func mtkView(_: MTKView, drawableSizeWillChange _: CGSize) {
		renderer?.seedAnimationTiming()
		requestFrame()
	}

	func draw(in _: MTKView) {
		let now = CACurrentMediaTime()
		guard canRender,
		      bounds.width > 0, bounds.height > 0,
		      frameScheduler.shouldRender(
		      	now: now,
		      	isAnimating: !isPaused,
		      	framesPerSecond: configuration.framesPerSecond
		      ),
		      hasVisibleDrawableArea,
		      let drawable = currentDrawable
		else {
			return
		}
		frameScheduler.didRender(now: now)
		do {
			if renderer == nil {
				let created = try DitherMetalRenderer(usesTopBlur: configuration.topBlur)
				renderer = created
				device = created.device
				created.seedAnimationTiming()
			}
			var frameConfiguration = configuration
			if reduceMotion || configuration.disableAnimation {
				frameConfiguration.disableAnimation = true
				frameConfiguration.intro = false
			}
			var inputs: DitherRenderInputs = if frameConfiguration.cursorInteractionEnabled, !frameConfiguration.disableAnimation {
				interaction.inputs(
					location: inputStorage?.location,
					now: now,
					configuration: frameConfiguration
				)
			} else {
				.empty
			}
			applyDeviceCorners(to: &inputs)
			try renderer?.render(
				to: drawable,
				size: bounds.size,
				configuration: frameConfiguration,
				inputs: inputs,
				advance: !isPaused
			)
		} catch {
			failed = true
			updateScheduling()
			NSLog("DitherView render failed: %@", error.localizedDescription)
			renderFallback(to: drawable)
		}
	}

	/// The largest radius the probe has reported. It reads 0 while the view sits in a transition, so this only ever goes up.
	private static var knownDeviceCornerRadius: CGFloat = 0

	/// Passes the screen's rounded rectangle, in this view's coordinates, so the
	/// shader can skip cells that would sit under the device's corners.
	private func applyDeviceCorners(to inputs: inout DitherRenderInputs) {
		#if os(iOS)
			guard configuration.clipsToDeviceCorners else {
				return
			}
			let measured = cornerProbe.effectiveRadius(corner: .allCorners)
			if measured > Self.knownDeviceCornerRadius {
				Self.knownDeviceCornerRadius = measured
			}
			let radius = Self.knownDeviceCornerRadius
			guard radius > 0 else {
				return
			}
			// A screen-sized view is clipped to its own bounds. Asking where the screen is mid-transition, while an
			// ancestor is moved or scaled, puts the corners somewhere other than the view's own and they stop clipping.
			let rect = if let screen = window?.windowScene?.screen, bounds.size != screen.bounds.size {
				screen.coordinateSpace.convert(screen.bounds, to: self)
			} else {
				bounds
			}
			inputs.screenOrigin = SIMD2<Float>(Float(rect.minX), Float(rect.minY))
			inputs.screenSize = SIMD2<Float>(Float(rect.width), Float(rect.height))
			inputs.screenCornerRadius = Float(radius)
		#endif
	}

	private func renderFallback(to drawable: CAMetalDrawable) {
		guard let queue = device?.makeCommandQueue(),
		      let buffer = queue.makeCommandBuffer()
		else {
			return
		}
		let pass = MTLRenderPassDescriptor()
		pass.colorAttachments[0].texture = drawable.texture
		pass.colorAttachments[0].loadAction = .clear
		pass.colorAttachments[0].storeAction = .store
		let color = configuration.backgroundColor
		pass.colorAttachments[0].clearColor = MTLClearColor(
			red: Double(color.x),
			green: Double(color.y),
			blue: Double(color.z),
			alpha: configuration.transparent ? 0 : 1
		)
		buffer.makeRenderCommandEncoder(descriptor: pass)?.endEncoding()
		buffer.present(drawable)
		buffer.commit()
	}
}

/// Input coordinates stay in points; the renderer converts them to drawable pixels.
private struct DitherInteraction {
	private var position: SIMD2<Float>?
	private var lastTime: TimeInterval?
	private var presence: Float = 0
	private var history: [(time: TimeInterval, position: SIMD2<Float>)] = []

	mutating func inputs(
		location: CGPoint?,
		now: TimeInterval,
		configuration: DitherConfiguration
	) -> DitherRenderInputs {
		guard configuration.cursorInteractionEnabled, !configuration.disableAnimation else {
			self = Self()
			return .empty
		}
		let delta = max(0, now - (lastTime ?? now))
		lastTime = now
		if let location {
			let target = SIMD2<Float>(Float(location.x), Float(location.y))
			if let previous = position {
				let blend = Float(1 - exp(-delta / configuration.cursorResponse))
				position = previous + (target - previous) * blend
			} else {
				position = target
			}
			presence = 1
		} else {
			presence = max(0, presence - Float(delta / configuration.cursorFadeDuration))
		}
		guard let position, presence > 0 else {
			self = Self()
			return .empty
		}
		history.append((now, position))
		let cutoff = now - configuration.cursorTrailDuration
		// Keep one sample before the cutoff for interpolation.
		while history.count > 1, history[1].time < cutoff {
			history.removeFirst()
		}
		var trail: [SIMD3<Float>] = []
		for index in 0 ..< 8 {
			let fraction = Double(index) / 7
			let time = now - configuration.cursorTrailDuration * fraction
			let sample = interpolatedPosition(at: time)
			// The shader uses sample.z for influence, reach, and warp.
			let strength = presence * Float(1 - fraction * 0.8)
			trail.append(SIMD3<Float>(sample.x, sample.y, strength))
		}
		return DitherRenderInputs(
			cursorTrail: trail,
			cursorTouch: position,
			cursorPresence: presence
		)
	}

	private func interpolatedPosition(at time: TimeInterval) -> SIMD2<Float> {
		guard let first = history.first else {
			return .zero
		}
		var previous = first
		for sample in history.dropFirst() {
			if sample.time >= time {
				let duration = sample.time - previous.time
				let blend = duration > 0 ? Float(min(1, max(0, (time - previous.time) / duration))) : 1
				return previous.position + (sample.position - previous.position) * blend
			}
			previous = sample
		}
		return previous.position
	}
}
