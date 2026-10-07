import Foundation

/// The sub-rectangle of the (mirrored) camera frame that maps onto the full
/// screen. Margins mean you never have to reach the edge of the camera's view
/// to reach the edge of the screen.
public struct InteractionBox: Codable, Equatable, Sendable {
    public var xMin: Double
    public var xMax: Double
    public var yMin: Double
    public var yMax: Double

    public init(xMin: Double = 0.15, xMax: Double = 0.85, yMin: Double = 0.18, yMax: Double = 0.82) {
        self.xMin = xMin
        self.xMax = xMax
        self.yMin = yMin
        self.yMax = yMax
    }

    public static let `default` = InteractionBox()

    /// Smallest half-extent a scaled box may keep on either axis. A box that
    /// crosses itself would fall through to `CoordinateMapper`'s 1e-6 guard
    /// and turn the cursor into a two-position switch, so the tightest mapping
    /// stays a usable 0.1 band of the camera view.
    public static let minHalfExtent: Double = 0.05

    /// The box with its half-extents multiplied by `factor` about its **own**
    /// centre, so an off-centre box (the auto-reach one is deliberately low,
    /// to leave headroom for the fingers) keeps its shape and only tightens.
    /// This is how the Cursor travel dial shortens a hand sweep: `factor` is
    /// `1 / cursorGain`, and every joint, overlay dot and the pointer keep
    /// sharing the one transform, because the change is in the box itself.
    public func scaledAboutCentre(by factor: Double) -> InteractionBox {
        // The dial's default is 1.0 and that path must hand back the box
        // bit-for-bit: manual reach runs this every frame, so a few parts in
        // 1e-16 of rounding drift here would re-map the cursor on every frame
        // of a session (and take `ReachMode.manual`'s "verbatim, never
        // drifts" contract with it).
        guard factor != 1 else { return self }
        let cx = (xMin + xMax) / 2
        let cy = (yMin + yMax) / 2
        let hx = max((xMax - xMin) / 2 * factor, Self.minHalfExtent)
        let hy = max((yMax - yMin) / 2 * factor, Self.minHalfExtent)
        return InteractionBox(xMin: cx - hx, xMax: cx + hx, yMin: cy - hy, yMax: cy + hy)
    }
}

/// Maps camera-normalized landmark positions (x right, y down, unmirrored) to
/// screen-normalized positions (x right, y down, top-left origin).
public struct CoordinateMapper: Codable, Equatable, Sendable {
    public var box: InteractionBox
    /// Mirror horizontally so moving your hand right moves the cursor right
    /// (webcam images are unmirrored; the user expects mirror behavior).
    public var mirrored: Bool

    public init(box: InteractionBox = .default, mirrored: Bool = true) {
        self.box = box
        self.mirrored = mirrored
    }

    /// Map a camera-space point into screen-normalized space.
    /// - Parameter clamped: clamp to [0,1] (use for the cursor; leave unclamped
    ///   for overlay fingertip dots so they can visibly run off-screen).
    public func map(_ cameraPoint: Vec2, clamped: Bool = true) -> Vec2 {
        let x = mirrored ? 1 - cameraPoint.x : cameraPoint.x
        let y = cameraPoint.y
        let w = max(box.xMax - box.xMin, 1e-6)
        let h = max(box.yMax - box.yMin, 1e-6)
        let mapped = Vec2((x - box.xMin) / w, (y - box.yMin) / h)
        return clamped ? mapped.clampedToUnit() : mapped
    }
}
