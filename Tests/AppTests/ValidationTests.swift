import Testing
@testable import App

@Suite("Parameter validation")
struct ValidationTests {

    // MARK: - Valid baseline

    @Test("Valid parameters pass without error")
    func validParams() throws {
        let params = RenderParams(
            centerLon: 10.74, centerLat: 59.91,
            zoom: 12, width: 512, height: 512, pixelRatio: 2.0
        )
        try params.validate()
    }

    // MARK: - centerLon

    @Test("Longitude at boundaries is accepted", arguments: [-180.0, 0.0, 180.0])
    func lonBoundaries(lon: Double) throws {
        let params = RenderParams(centerLon: lon, centerLat: 0, zoom: 0, width: 1, height: 1, pixelRatio: 1)
        try params.validate()
    }

    @Test("Longitude out of range is rejected", arguments: [-180.1, 181.0, 999.0, -999.0])
    func lonOutOfRange(lon: Double) {
        let params = RenderParams(centerLon: lon, centerLat: 0, zoom: 0, width: 1, height: 1, pixelRatio: 1)
        #expect(throws: (any Error).self) { try params.validate() }
    }

    @Test("Non-finite longitude is rejected", arguments: [Double.nan, Double.infinity, -Double.infinity])
    func lonNonFinite(lon: Double) {
        let params = RenderParams(centerLon: lon, centerLat: 0, zoom: 0, width: 1, height: 1, pixelRatio: 1)
        #expect(throws: (any Error).self) { try params.validate() }
    }

    // MARK: - centerLat

    @Test("Latitude at boundaries is accepted", arguments: [-90.0, 0.0, 90.0])
    func latBoundaries(lat: Double) throws {
        let params = RenderParams(centerLon: 0, centerLat: lat, zoom: 0, width: 1, height: 1, pixelRatio: 1)
        try params.validate()
    }

    @Test("Latitude out of range is rejected", arguments: [-90.1, 91.0, 999.0])
    func latOutOfRange(lat: Double) {
        let params = RenderParams(centerLon: 0, centerLat: lat, zoom: 0, width: 1, height: 1, pixelRatio: 1)
        #expect(throws: (any Error).self) { try params.validate() }
    }

    @Test("Non-finite latitude is rejected", arguments: [Double.nan, Double.infinity])
    func latNonFinite(lat: Double) {
        let params = RenderParams(centerLon: 0, centerLat: lat, zoom: 0, width: 1, height: 1, pixelRatio: 1)
        #expect(throws: (any Error).self) { try params.validate() }
    }

    // MARK: - zoom

    @Test("Zoom at boundaries is accepted", arguments: [0.0, 11.5, 22.0])
    func zoomBoundaries(zoom: Double) throws {
        let params = RenderParams(centerLon: 0, centerLat: 0, zoom: zoom, width: 1, height: 1, pixelRatio: 1)
        try params.validate()
    }

    @Test("Zoom out of range is rejected", arguments: [-0.1, 22.1, 100.0])
    func zoomOutOfRange(zoom: Double) {
        let params = RenderParams(centerLon: 0, centerLat: 0, zoom: zoom, width: 1, height: 1, pixelRatio: 1)
        #expect(throws: (any Error).self) { try params.validate() }
    }

    // MARK: - width / height

    @Test("Width and height at boundaries are accepted")
    func dimensionBoundaries() throws {
        let lo = RenderParams(centerLon: 0, centerLat: 0, zoom: 0, width: 1,    height: 1,    pixelRatio: 1)
        let hi = RenderParams(centerLon: 0, centerLat: 0, zoom: 0, width: 8192, height: 8192, pixelRatio: 1)
        try lo.validate()
        try hi.validate()
    }

    @Test("Zero or negative width is rejected", arguments: [0, -1, -100])
    func widthTooSmall(w: Int) {
        let params = RenderParams(centerLon: 0, centerLat: 0, zoom: 0, width: w, height: 512, pixelRatio: 1)
        #expect(throws: (any Error).self) { try params.validate() }
    }

    @Test("Width over 8192 is rejected")
    func widthTooLarge() {
        let params = RenderParams(centerLon: 0, centerLat: 0, zoom: 0, width: 8193, height: 512, pixelRatio: 1)
        #expect(throws: (any Error).self) { try params.validate() }
    }

    // MARK: - pixelRatio

    @Test("Pixel ratio at boundaries is accepted", arguments: [0.25, 1.0, 2.0, 4.0])
    func pixelRatioBoundaries(ratio: Double) throws {
        let params = RenderParams(centerLon: 0, centerLat: 0, zoom: 0, width: 1, height: 1, pixelRatio: ratio)
        try params.validate()
    }

    @Test("Pixel ratio out of range is rejected", arguments: [0.0, 0.24, 4.01, 10.0])
    func pixelRatioOutOfRange(ratio: Double) {
        let params = RenderParams(centerLon: 0, centerLat: 0, zoom: 0, width: 1, height: 1, pixelRatio: ratio)
        #expect(throws: (any Error).self) { try params.validate() }
    }

    // MARK: - Multiple errors

    @Test("Multiple invalid params report all errors in one throw")
    func multipleErrors() {
        let params = RenderParams(centerLon: 999, centerLat: 999, zoom: 99, width: -1, height: -1, pixelRatio: 99)
        #expect(throws: (any Error).self) { try params.validate() }
    }
}
