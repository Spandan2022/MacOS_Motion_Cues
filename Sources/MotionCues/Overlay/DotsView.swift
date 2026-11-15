// Motion Cues — vehicle motion cues for macOS
// Copyright (C) 2026 Spandan2022 and contributors
// SPDX-License-Identifier: GPL-3.0-or-later

import AppKit
import QuartzCore

/// Draws iOS-style Vehicle Motion Cues on one screen: endless columns of dots along the
/// left and right edges.
///
/// - Speeding up / braking makes the columns *flow* down / up. Acceleration sets the speed,
///   so during a long brake the dots keep streaming off the top of the screen while new
///   ones slowly come in from the bottom, like an endless column. When the motion stops, they stop.
/// - Turning makes the two sides flow in opposite directions (left side up, right side down
///   when turning left), like the scenery rotating around you.
/// - Sideways force pushes the columns sideways; strong pushes carry them past the edge.
/// - Dots grow a little with motion, and a second, inner column grows in when it's strong.
final class DotsView: NSView {
    /// Supplies the latest cue each frame.
    var cueProvider: () -> MotionCue = { MotionCue() }
    /// Scales dot size and spacing, for drawing the dots on a miniature screen (Welcome Guide).
    var scale: CGFloat = 1 { didSet { rebuildDots() } }
    /// A dot color that overrides the color setting (Welcome Guide).
    var colorOverride: DotColor? { didSet { rebuildDots() } }

    private struct Dot {
        let layer: CALayer
        let side: CGFloat   // -1 = left edge, +1 = right edge
        let inner: Bool     // second column
        let index: Int      // position in its column
    }

    private var dots: [Dot] = []
    private var displayLink: CADisplayLink?
    private var lastTimestamp: CFTimeInterval?

    /// Vertical flow position and its (smoothed) speed, in points.
    private var flow: CGFloat = 0
    private var flowSpeed: CGFloat = 0
    /// Opposite flow of the two sides from turning, and its speed.
    private var turnFlow: CGFloat = 0
    private var turnSpeed: CGFloat = 0
    /// Sideways spring.
    private var offsetX: CGFloat = 0
    private var velocityX: CGFloat = 0
    private var smoothedTargetX: CGFloat = 0
    /// Smoothed 0…1 amount of motion; grows the dots and brings in the inner column.
    private var intensity: CGFloat = 0

    private let speedSmoothing: CGFloat = 0.3  // s; how quickly the flow speed follows motion
    private let springOmega: CGFloat = 6       // rad/s for sideways movement (soft, ~0.6 s settle)
    private let lateralSmoothing: CGFloat = 0.25 // s; smooths the sideways target

    private var dotSize: CGFloat { Settings.shared.dotSize.points * scale }
    private var spacing: CGFloat { dotSize * Settings.shared.density.spacingFactor }
    private var columnSpan: CGFloat { CGFloat(dotsPerColumn) * spacing }
    private var dotsPerColumn = 0

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer = CALayer()
        layer?.backgroundColor = NSColor.clear.cgColor
    }

    required init?(coder: NSCoder) { fatalError() }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        displayLink?.invalidate()
        displayLink = nil
        guard window != nil else { return }
        rebuildDots()
        let link = displayLink(target: self, selector: #selector(step(_:)))
        link.preferredFrameRateRange = CAFrameRateRange(minimum: 30, maximum: 60, preferred: 60)
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    override func layout() {
        super.layout()
        rebuildDots()
    }

    func stopAnimating() {
        displayLink?.invalidate()
        displayLink = nil
    }

    /// Recreate the dot layers to match the current settings and size.
    func rebuildDots() {
        dots.forEach { $0.layer.removeFromSuperlayer() }
        dots.removeAll()

        let size = dotSize
        // Enough dots to cover the screen plus one spare above and below, so the column
        // looks endless as it flows.
        dotsPerColumn = Int(ceil(bounds.height / spacing)) + 2
        let scale = window?.backingScaleFactor ?? 2
        let color = colorOverride ?? Settings.shared.color
        let fill = color.fill.cgColor
        // Translucent, so whatever is under each dot stays visible.
        let opacity = Settings.shared.opacity.value

        for side: CGFloat in [-1, 1] {
            for inner in [false, true] {
                for i in 0..<dotsPerColumn {
                    let l = CALayer()
                    l.bounds = CGRect(x: 0, y: 0, width: size, height: size)
                    l.cornerRadius = size / 2
                    l.backgroundColor = fill
                    l.opacity = colorOverride == nil ? opacity : 0.9
                    l.contentsScale = scale
                    l.actions = ["position": NSNull(), "transform": NSNull(), "hidden": NSNull()]
                    layer?.addSublayer(l)
                    dots.append(Dot(layer: l, side: side, inner: inner, index: i))
                }
            }
        }
        positionDots()
    }

    @objc private func step(_ link: CADisplayLink) {
        let now = link.timestamp
        let dt = CGFloat(min(max(now - (lastTimestamp ?? now), 0), 0.05))
        lastTimestamp = now
        advance(by: dt, cue: cueProvider())
    }

    /// Moves the animation forward by `dt` seconds toward the given cue.
    func advance(by dt: CGFloat, cue: MotionCue) {
        let gain = CGFloat(Settings.shared.sensitivity.gain)
        let fwd = CGFloat(cue.forward) * gain
        let lat = CGFloat(cue.lateral) * gain
        let yaw = CGFloat(cue.yawRate) * gain
        let k = min(1, dt / speedSmoothing)

        // Flow speed ∝ acceleration; dots move opposite to it (inertia). Screen up = forward.
        // 0.1 g → 0.4 dot-spacings per second (gentle, like iOS), capped at 1.2 spacings/s.
        let maxSpeed = spacing * 1.2
        var targetSpeed = -fwd * spacing * 4
        targetSpeed = maxSpeed * tanh(targetSpeed / maxSpeed)
        flowSpeed += (targetSpeed - flowSpeed) * k
        flow += flowSpeed * dt

        // Turning left (positive yaw): left side flows up, right side down. 30°/s → 0.3 spacing/s.
        let maxTurn = spacing * 0.8
        let targetTurn = maxTurn * tanh(yaw * spacing / 100 / maxTurn)
        turnSpeed += (targetTurn - turnSpeed) * k
        turnFlow += turnSpeed * dt

        if columnSpan > 0 {
            flow = flow.truncatingRemainder(dividingBy: columnSpan)
            turnFlow = turnFlow.truncatingRemainder(dividingBy: columnSpan)
        }

        // Sideways: spring toward an offset ∝ lateral force.
        let maxX = dotSize * 4
        var targetX = -lat * dotSize * 32
        targetX = maxX * tanh(targetX / maxX)
        smoothedTargetX += (targetX - smoothedTargetX) * min(1, dt / lateralSmoothing)
        let w = springOmega
        velocityX += (w * w * (smoothedTargetX - offsetX) - 2 * w * velocityX) * dt
        offsetX += velocityX * dt

        let raw = min(1, hypot(fwd, lat) / 0.22 + abs(yaw) / 28)
        let rate: CGFloat = raw > intensity ? 6 : 1.2   // grow fairly quickly, settle slowly
        intensity += (raw - intensity) * min(1, rate * dt)

        positionDots()
    }

    private func positionDots() {
        guard !dots.isEmpty, columnSpan > 0 else { return }
        let size = dotSize
        let gap = spacing
        let span = columnSpan
        // At rest the outer column sits a little inside the edge.
        let edgeInset = size * 1.9
        let innerShift = size * 3.6

        let outerScale = 0.75 + 0.25 * intensity
        let innerAmount = smoothstep((intensity - 0.5) / 0.4)

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        for dot in dots {
            var x = dot.side < 0 ? edgeInset : bounds.width - edgeInset
            if dot.inner { x -= dot.side * innerShift }
            x += offsetX

            // Evenly spaced, inner column staggered by half a step; wraps from one end of the
            // (slightly taller than the screen) column to the other while off-screen.
            var y = CGFloat(dot.index) * gap + (dot.inner ? gap / 2 : 0)
            y += flow + (dot.side < 0 ? turnFlow : -turnFlow)
            y = y.truncatingRemainder(dividingBy: span)
            if y < 0 { y += span }
            y -= gap

            var s = dot.inner ? innerAmount : outerScale
            // Near the top and bottom of the screen, dots grow from nothing to full size
            // as they come in (and shrink away as they leave).
            let fromEdge = min(y, bounds.height - y)
            s *= smoothstep(fromEdge / (gap * 0.7))
            if dot.inner {
                // Inner dots shrink away if a sideways push carries them off-screen.
                let inside = min(x, bounds.width - x)
                s *= smoothstep(inside / (size * 0.8))
            }

            dot.layer.isHidden = s < 0.03
            if !dot.layer.isHidden {
                dot.layer.position = CGPoint(x: x, y: y)
                dot.layer.transform = CATransform3DMakeScale(s, s, 1)
            }
        }
        CATransaction.commit()
    }

    private func smoothstep(_ t: CGFloat) -> CGFloat {
        let c = min(max(t, 0), 1)
        return c * c * (3 - 2 * c)
    }
}
