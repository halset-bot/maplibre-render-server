import Vapor

/// Query parameters for the /render endpoint.
struct RenderParams: Content {
    let centerLon: Double
    let centerLat: Double
    let zoom: Double
    let width: Int
    let height: Int
    let pixelRatio: Double

    // MARK: - Validation

    /// Validates all parameters and throws a descriptive 400 if any are out of range.
    func validate() throws {
        var errors: [String] = []

        // Finite-number checks (guards against NaN / Inf slipping through)
        if !centerLon.isFinite  { errors.append("centerLon must be a finite number") }
        if !centerLat.isFinite  { errors.append("centerLat must be a finite number") }
        if !zoom.isFinite       { errors.append("zoom must be a finite number") }
        if !pixelRatio.isFinite { errors.append("pixelRatio must be a finite number") }

        // Geographic bounds
        if centerLon.isFinite, !((-180.0)...180.0 ~= centerLon) {
            errors.append("centerLon must be between -180 and 180 (got \(centerLon))")
        }
        if centerLat.isFinite, !((-90.0)...90.0 ~= centerLat) {
            errors.append("centerLat must be between -90 and 90 (got \(centerLat))")
        }

        // Zoom level
        if zoom.isFinite, !(0.0...22.0 ~= zoom) {
            errors.append("zoom must be between 0 and 22 (got \(zoom))")
        }

        // Dimensions — positive and capped to avoid runaway memory/GPU usage
        if width < 1 || width > 8192 {
            errors.append("width must be between 1 and 8192 (got \(width))")
        }
        if height < 1 || height > 8192 {
            errors.append("height must be between 1 and 8192 (got \(height))")
        }

        // Pixel ratio — covers 0.25× lo-res previews up to 4× high-density
        if pixelRatio.isFinite, !(0.25...4.0 ~= pixelRatio) {
            errors.append("pixelRatio must be between 0.25 and 4.0 (got \(pixelRatio))")
        }

        if !errors.isEmpty {
            throw Abort(.badRequest, reason: errors.joined(separator: "; "))
        }
    }
}
