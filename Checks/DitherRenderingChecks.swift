/// Invoked by run-dither-rendering-checks.py; appended to the actual renderer source.
@main
struct DitherBenchmark {
	@MainActor
	static func main() throws {
		let output = CommandLine.arguments[1]
		if CommandLine.arguments.contains("--verify-reuse") {
			let defaults = DitherConfiguration()
			precondition(!defaults.cursorInteractionEnabled && !defaults.topBlur)
			precondition(defaults.framesPerSecond == 5)
		}
		let width = 1290
		let height = 2796
		let device = MTLCreateSystemDefaultDevice()!
		print("Device: \(device.name)")
		let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm, width: width, height: height, mipmapped: false)
		descriptor.storageMode = .shared
		descriptor.usage = [.renderTarget, .shaderRead]
		var configuration = DitherConfiguration()
		configuration.intro = false
		configuration.cursorInteractionEnabled = true
		configuration.pixelSize = 5
		configuration.gap = 0.2
		configuration.cornerRadius = 0.2
		configuration.palette = [SIMD3<Float>(0.478, 0.322, 0.188), SIMD3<Float>(0.788, 0.627, 0.478)]
		for scenario in ["detail", "interactive", "blur", "joined", "plain", "theme", "transparent", "cell-blur", "padding"] {
			let width = scenario == "cell-blur" ? 320 : scenario == "padding" ? 333 : width
			let height = scenario == "cell-blur" ? 640 : scenario == "padding" ? 587 : height
			descriptor.width = width
			descriptor.height = height
			let target = device.makeTexture(descriptor: descriptor)!
			let cell = scenario == "cell-blur" ? 8 : 15
			let scale: Float = scenario == "cell-blur" ? 2 : 3
			configuration.topBlur = scenario == "blur" || scenario == "cell-blur"
			configuration.transparent = scenario == "transparent"
			configuration.useThemeColors = scenario == "theme"
			configuration.joinAdjacentSquares = scenario == "joined"
			configuration.gap = scenario == "joined" || scenario == "plain" || scenario == "cell-blur" ? 0 : 0.2
			configuration.cornerRadius = scenario == "plain" || scenario == "cell-blur" ? 0 : 0.2
			let renderer = try DitherMetalRenderer(usesTopBlur: configuration.topBlur, blurScale: scale)
			var inputs = DitherRenderInputs()
			if scenario == "interactive" {
				inputs.cursorPresence = 1
				inputs.cursorTouch = SIMD2<Float>(150, 300)
				inputs.cursorTrail = (0 ..< 8).map { SIMD3<Float>(150 + Float($0), 300 + Float($0), 1 - Float($0) * 0.1) }
			}
			if scenario == "theme" {
				inputs.themeColors = [SIMD3<Float>(1, 0, 0), SIMD3<Float>(0, 0, 1)]
				inputs.themePositions = [SIMD2<Float>(0.2, 0.2), SIMD2<Float>(0.8, 0.8)]
			}
			var cpu: [Double] = []
			var gpu: [Double] = []
			for frame in 0 ..< 45 {
				try renderer.render(to: target, width: width, height: height, cell: cell, configuration: configuration, inputs: inputs, advance: false, atTime: Float(frame) / 30)
				if frame >= 10, let metrics = renderer.lastRenderMetrics {
					cpu.append(metrics.cpuElapsed * 1000)
					gpu.append((metrics.gpuElapsed ?? 0) * 1000)
				}
			}
			if scenario == "detail", CommandLine.arguments.contains("--verify-reuse") {
				renderer.checkUnusedResources()
				let sibling = try DitherMetalRenderer(usesTopBlur: false)
				renderer.checkSharedQueue(with: sibling)
				try sibling.render(to: target, width: width, height: height, cell: cell, configuration: configuration, inputs: inputs, advance: false, atTime: 44.0 / 30)
				precondition(sibling.lastRenderMetrics?.computeDispatchCount == 1, "Matching renderer regenerated coverage")
				print("Resource checks passed: unused pipelines deferred, shared queue, and reused coverage")
			}
			cpu.sort()
			gpu.sort()
			print("\(scenario) CPU median ms \(cpu[cpu.count / 2]) GPU median ms \(gpu[gpu.count / 2])")
			var bytes = [UInt8](repeating: 0, count: width * height * 4)
			bytes.withUnsafeMutableBytes {
				target.getBytes($0.baseAddress!, bytesPerRow: width * 4, from: MTLRegionMake2D(0, 0, width, height), mipmapLevel: 0)
			}
			try Data(bytes).write(to: URL(fileURLWithPath: "\(output)/\(scenario).bgra"))
		}

		// Submit renderers together and exceed the atlas cache limit while frames are in flight.
		descriptor.width = 430
		descriptor.height = 932
		var renderers: [DitherMetalRenderer] = []
		var targets: [MTLTexture] = []
		for index in 0 ..< 16 {
			let renderer = try DitherMetalRenderer(usesTopBlur: false)
			let target = device.makeTexture(descriptor: descriptor)!
			var config = DitherConfiguration()
			config.intro = false
			config.topBlur = false
			config.cursorInteractionEnabled = false
			config.gap = index < 3 ? 0.2 : index < 6 ? 0 : Float(index) * 0.02
			config.cornerRadius = 0.2
			config.joinAdjacentSquares = index >= 3 && index < 6
			try renderer.submitCheckFrame(to: target, configuration: config, time: Float(index))
			renderers.append(renderer)
			targets.append(target)
		}
		for renderer in renderers {
			try renderer.finishCheckFrames()
		}
		for (index, target) in targets.enumerated() {
			var bytes = [UInt8](repeating: 0, count: 430 * 932 * 4)
			bytes.withUnsafeMutableBytes {
				target.getBytes($0.baseAddress!, bytesPerRow: 430 * 4, from: MTLRegionMake2D(0, 0, 430, 932), mipmapLevel: 0)
			}
			try Data(bytes).write(to: URL(fileURLWithPath: "\(output)/multi-\(index).bgra"))
		}
	}
}

private extension DitherMetalRenderer {
	func checkSharedQueue(with other: DitherMetalRenderer) {
		precondition(queue === other.queue)
		precondition(sharedGradientResourceIdentifier == other.sharedGradientResourceIdentifier)
	}

	func checkUnusedResources() {
		let stored = Mirror(reflecting: self).children.first { $0.label == "sharedResources" }!.value
		let unused = Set(["fieldPipeline", "cellPipeline", "referenceDitherPipeline", "blurCompositePipeline", "cellBlurHorizontalPipeline", "cellBlurCompositePipeline"])
		var checked = 0
		for field in Mirror(reflecting: stored).children where unused.contains(field.label ?? "") {
			let optional = Mirror(reflecting: field.value)
			precondition(optional.displayStyle == .optional && optional.children.isEmpty, "Unused pipeline was compiled: \(field.label!)")
			checked += 1
		}
		precondition(checked == unused.count)
		for field in Mirror(reflecting: self).children where ["joinMaskTexture", "topBlurResources", "cellBlurResources"].contains(field.label ?? "") {
			precondition(Mirror(reflecting: field.value).children.isEmpty, "Unused texture resource was allocated")
		}
	}

	func submitCheckFrame(to target: MTLTexture, configuration: DitherConfiguration, time: Float) throws {
		try render(to: target, width: 430, height: 932, cell: 5, configuration: configuration, inputs: .empty, advance: false, atTime: time, drawable: nil, waitUntilCompleted: false, scale: 1)
	}

	func finishCheckFrames() throws {
		let command = queue.makeCommandBuffer()!
		command.commit()
		command.waitUntilCompleted()
		if let error = command.error {
			throw error
		}
	}
}
