import Vapor

public func configure(_ app: Application) throws {
    app.http.server.configuration.port = 8080

    // Allow large style JSON payloads
    app.routes.defaultMaxBodySize = "10mb"

    try routes(app)
}
