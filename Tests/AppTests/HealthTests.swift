import Testing
import VaporTesting
@testable import App

@Suite("Health endpoint")
struct HealthTests {

    @Test("GET /health returns 200 and ok status")
    func healthReturnsOK() async throws {
        try await withApp { app in
            try await app.testing().test(.GET, "health") { res async throws in
                #expect(res.status == .ok)
                let body = try res.content.decode(HealthBody.self)
                #expect(body.status == "ok")
            }
        }
    }

    @Test("GET /health includes cache pool stats")
    func healthIncludesPoolStats() async throws {
        try await withApp { app in
            try await app.testing().test(.GET, "health") { res async throws in
                #expect(res.status == .ok)
                let body = try res.content.decode(HealthBody.self)
                #expect(body.cachePoolTotal >= 0)
                #expect(body.cachePoolActive >= 0)
            }
        }
    }

    @Test("POST /render with missing body returns 400")
    func renderMissingBody() async throws {
        try await withApp { app in
            try await app.testing().test(
                .POST,
                "render?centerLon=10&centerLat=59&zoom=12&width=256&height=256&pixelRatio=1"
            ) { res async in
                #expect(res.status == .badRequest)
            }
        }
    }

    @Test("POST /render with invalid params returns 400")
    func renderInvalidParams() async throws {
        try await withApp { app in
            try await app.testing().test(
                .POST,
                "render?centerLon=999&centerLat=59&zoom=12&width=256&height=256&pixelRatio=1",
                beforeRequest: { req in
                    req.body = .init(string: "{}")
                    req.headers.contentType = .json
                }
            ) { res async in
                #expect(res.status == .badRequest)
            }
        }
    }
}

// MARK: - Helpers

/// Boots a test application, runs the closure, then shuts down cleanly.
private func withApp(_ closure: (Application) async throws -> Void) async throws {
    let app = try await Application.make(.testing)
    try configure(app)
    try await app.startup()  // initialises the router so routes are reachable
    do {
        try await closure(app)
    } catch {
        try await app.asyncShutdown()
        throw error
    }
    try await app.asyncShutdown()
}

/// Mirrors the public HealthResponse struct for decoding in tests.
private struct HealthBody: Decodable {
    let status: String
    let cachePoolTotal: Int
    let cachePoolActive: Int
}
