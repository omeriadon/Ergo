// Run with Xcode MCP RunCodeSnippet in the context of DitherView.swift.
import Foundation

var scheduler = DitherFrameScheduler()
precondition(scheduler.shouldRender(now: 0, isAnimating: true))
scheduler.didRender(now: 0)
precondition(!scheduler.shouldRender(now: 0.199, isAnimating: true))
precondition(scheduler.shouldRender(now: 0.2, isAnimating: true))
scheduler.didRender(now: 0.2)

// Pointer and layout invalidations must not bypass the animation cap.
for tick in 201 ..< 400 {
	scheduler.requestFrame()
	precondition(!scheduler.shouldRender(now: Double(tick) / 1000, isAnimating: true))
}

precondition(scheduler.shouldRender(now: 0.4, isAnimating: true))
scheduler.didRender(now: 0.4)

// Static changes render immediately, then remain idle.
scheduler.requestFrame()
precondition(scheduler.shouldRender(now: 0.401, isAnimating: false))
scheduler.didRender(now: 0.401)
precondition(!scheduler.shouldRender(now: 0.402, isAnimating: false))

// A missing drawable must not consume the pending static update.
scheduler.requestFrame()
precondition(scheduler.shouldRender(now: 0.403, isAnimating: false))
precondition(scheduler.shouldRender(now: 0.404, isAnimating: false))
scheduler.didRender(now: 0.404)
precondition(!scheduler.shouldRender(now: 0.405, isAnimating: false))

var burstScheduler = DitherFrameScheduler()
var rendered = 0
for tick in 0 ..< 10000 {
	let now = Double(tick) / 1000
	burstScheduler.requestFrame()
	if burstScheduler.shouldRender(now: now, isAnimating: true) {
		if let previous = burstScheduler.lastRenderTime {
			precondition(now - previous >= 0.2)
		}
		burstScheduler.didRender(now: now)
		rendered += 1
	}
}

precondition(rendered >= 49 && rendered <= 50)

/// AboutView can use 30 fps while other dither instances retain the 5 fps default.
var aboutScheduler = DitherFrameScheduler()
aboutScheduler.didRender(now: 0)
precondition(!aboutScheduler.shouldRender(now: 0.03, isAnimating: true, framesPerSecond: 30))
precondition(aboutScheduler.shouldRender(now: 1.0 / 30, isAnimating: true, framesPerSecond: 30))
var defaultScheduler = DitherFrameScheduler()
defaultScheduler.didRender(now: 0)
precondition(!defaultScheduler.shouldRender(now: 1.0 / 30, isAnimating: true))

/// Cadence changes must preserve elapsed animation time; resuming excludes idle time.
var timing = DitherAnimationTiming()
timing.seed(now: 0)
precondition(timing.advance(now: 0.1, isAdvancing: true) == 0.1)
precondition(timing.advance(now: 0.3, isAdvancing: true) > 0.19)
timing.seed(now: 10)
precondition(timing.advance(now: 10.1, isAdvancing: true) < 0.101)

print("Dither scheduling checks passed: per-view 5/30 fps caps, burst invalidation, static redraw, drawable retry, and elapsed animation time.")
