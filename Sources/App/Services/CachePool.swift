import Foundation

/// Thread-safe pool of SQLite cache database files for mbgl-render.
///
/// mbgl-render uses a SQLite database to cache downloaded tiles. Concurrent
/// processes can't safely share one database, so each active render gets its
/// own file checked out from this pool.
///
/// Entries are reused across requests to benefit from cached tiles, then
/// retired and deleted once they reach `maxUses`.
actor CachePool {

    // MARK: - Shared instance

    static let shared = CachePool()

    // MARK: - Types

    private struct Entry {
        let path: String
        var useCount: Int = 0
        var inUse: Bool = false
    }

    // MARK: - State

    private var entries: [Entry] = []
    private let maxUses: Int

    // MARK: - Init

    init(maxUses: Int = 20) {
        self.maxUses = maxUses
    }

    // MARK: - Public interface

    /// Checks out a cache database path.
    ///
    /// Returns a free existing entry if one is available; otherwise creates
    /// a new database file in /tmp. The caller **must** call `checkin(path:)`
    /// when the render process finishes.
    func checkout() -> String {
        // Reuse the first free entry that hasn't expired
        if let index = entries.indices.first(where: { !entries[$0].inUse }) {
            entries[index].inUse = true
            return entries[index].path
        }
        // Allocate a fresh database file
        let path = FileManager.default.temporaryDirectory
            .appendingPathComponent("mbgl-cache-\(UUID().uuidString).db")
            .path
        entries.append(Entry(path: path, useCount: 0, inUse: true))
        return entries.last!.path
    }

    /// Returns a cache database to the pool after a render completes.
    ///
    /// Increments the use count. If the entry has reached `maxUses` it is
    /// removed from the pool and its file is deleted from disk.
    func checkin(path: String) {
        guard let index = entries.firstIndex(where: { $0.path == path }) else { return }
        entries[index].inUse = false
        entries[index].useCount += 1

        if entries[index].useCount >= maxUses {
            let retiring = entries.remove(at: index)
            try? FileManager.default.removeItem(atPath: retiring.path)
        }
    }

    // MARK: - Diagnostics

    /// Current number of database files in the pool (for /health reporting).
    var count: Int { entries.count }

    /// Number of databases currently checked out.
    var activeCount: Int { entries.filter(\.inUse).count }
}
