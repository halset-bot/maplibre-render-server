import Foundation

enum RenderError: Error, LocalizedError {
    case mbglRenderNotFound(String)
    case processFailed(exitCode: Int32, stderr: String)
    case outputMissing

    var errorDescription: String? {
        switch self {
        case .mbglRenderNotFound(let path):
            return "mbgl-render not found at '\(path)'. Set MBGL_RENDER_PATH env var or place it in /usr/local/bin."
        case .processFailed(let code, let stderr):
            return "mbgl-render exited with code \(code): \(stderr)"
        case .outputMissing:
            return "mbgl-render succeeded but produced no output file."
        }
    }
}

struct MapRenderer {

    /// Renders a MapLibre map to PNG by spawning an mbgl-render subprocess.
    ///
    /// Each call gets its own temp files and its own process, so multiple
    /// calls run concurrently without coordination. A shared `CachePool`
    /// provides each process with a reusable SQLite tile cache.
    static func render(
        styleData: Data,
        centerLon: Double,
        centerLat: Double,
        zoom: Double,
        width: Int,
        height: Int,
        pixelRatio: Double
    ) async throws -> Data {

        let mbglPath = resolvedMbglRenderPath()
        guard FileManager.default.fileExists(atPath: mbglPath) else {
            throw RenderError.mbglRenderNotFound(mbglPath)
        }

        let id = UUID().uuidString
        let tmpDir = FileManager.default.temporaryDirectory
        let styleURL  = tmpDir.appendingPathComponent("\(id)-style.json")
        let outputURL = tmpDir.appendingPathComponent("\(id)-output.png")

        defer {
            try? FileManager.default.removeItem(at: styleURL)
            try? FileManager.default.removeItem(at: outputURL)
        }

        try styleData.write(to: styleURL)

        // Checkout a reusable tile cache; checkin happens regardless of outcome.
        return try await withCacheDatabase { cachePath in
            let (exitCode, stderr) = try await spawnProcess(
                executable: mbglPath,
                arguments: [
                    "--style",  styleURL.path,
                    "--lon",    formatted(centerLon),
                    "--lat",    formatted(centerLat),
                    "--zoom",   formatted(zoom),
                    "--width",  String(width),
                    "--height", String(height),
                    "--ratio",  formatted(pixelRatio),
                    "--cache",  cachePath,
                    "--output", outputURL.path,
                ]
            )

            guard exitCode == 0 else {
                throw RenderError.processFailed(exitCode: exitCode, stderr: stderr)
            }

            guard let pngData = try? Data(contentsOf: outputURL) else {
                throw RenderError.outputMissing
            }

            return pngData
        }
    }

    // MARK: - Cache pool helper

    /// Checks out a cache database, runs `work`, then checks the database back
    /// in — whether the work succeeds or throws.
    private static func withCacheDatabase<T>(
        _ work: (String) async throws -> T
    ) async throws -> T {
        let cachePath = await CachePool.shared.checkout()
        let result: Result<T, Error>
        do {
            result = .success(try await work(cachePath))
        } catch {
            result = .failure(error)
        }
        await CachePool.shared.checkin(path: cachePath)
        return try result.get()
    }

    // MARK: - Process spawning

    /// Spawns a subprocess and returns its (terminationStatus, stderr) asynchronously.
    private static func spawnProcess(
        executable: String,
        arguments: [String]
    ) async throws -> (Int32, String) {
        try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: executable)
            process.arguments = arguments

            let stdoutPipe = Pipe()
            let stderrPipe = Pipe()
            process.standardOutput = stdoutPipe  // discard
            process.standardError  = stderrPipe

            process.terminationHandler = { p in
                let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
                let stderrStr  = String(data: stderrData, encoding: .utf8) ?? ""
                continuation.resume(returning: (p.terminationStatus, stderrStr))
            }

            do {
                try process.run()
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    // MARK: - Helpers

    /// Resolves the mbgl-render binary path.
    /// Reads MBGL_RENDER_PATH env var; falls back to /usr/local/bin/mbgl-render.
    private static func resolvedMbglRenderPath() -> String {
        ProcessInfo.processInfo.environment["MBGL_RENDER_PATH"] ?? "/usr/local/bin/mbgl-render"
    }

    /// Formats a Double for CLI arguments (no scientific notation).
    private static func formatted(_ value: Double) -> String {
        String(format: "%g", value)
    }
}
