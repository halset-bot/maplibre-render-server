import Vapor

func routes(_ app: Application) throws {

    // GET /health — liveness check + cache pool stats
    app.get("health") { _ async -> HealthResponse in
        let total  = await CachePool.shared.count
        let active = await CachePool.shared.activeCount
        return HealthResponse(status: "ok", cachePoolTotal: total, cachePoolActive: active)
    }

    // POST /render
    // Query params: centerLon, centerLat, zoom, width, height, pixelRatio
    // Body:         MapLibre style JSON (application/json)
    // Response:     image/png
    app.post("render") { req async throws -> Response in
        // 1. Decode and validate query parameters
        let params = try req.query.decode(RenderParams.self)
        try params.validate()

        // 2. Read and sanity-check the request body
        guard let byteBuffer = req.body.data else {
            throw Abort(.badRequest, reason: "Missing style JSON in request body.")
        }
        let styleData = Data(byteBuffer.readableBytesView)

        guard !styleData.isEmpty else {
            throw Abort(.badRequest, reason: "Request body is empty.")
        }
        guard (try? JSONSerialization.jsonObject(with: styleData)) != nil else {
            throw Abort(.badRequest, reason: "Request body is not valid JSON.")
        }

        // 3. Render
        let pngData = try await MapRenderer.render(
            styleData: styleData,
            centerLon: params.centerLon,
            centerLat: params.centerLat,
            zoom: params.zoom,
            width: params.width,
            height: params.height,
            pixelRatio: params.pixelRatio
        )

        // 4. Return PNG
        var headers = HTTPHeaders()
        headers.add(name: .contentType, value: "image/png")
        return Response(status: .ok, headers: headers, body: .init(data: pngData))
    }
}

// MARK: - Health response

private struct HealthResponse: Content {
    let status: String
    let cachePoolTotal: Int   // databases in pool
    let cachePoolActive: Int  // currently checked out
}
