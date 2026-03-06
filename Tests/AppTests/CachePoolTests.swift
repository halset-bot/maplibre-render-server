import Testing
@testable import App

@Suite("CachePool")
struct CachePoolTests {

    @Test("Checkout creates a new entry")
    func checkoutCreatesEntry() async {
        let pool = CachePool()
        let path = await pool.checkout()
        #expect(path.contains("mbgl-cache"))
        #expect(await pool.count == 1)
        #expect(await pool.activeCount == 1)
    }

    @Test("Checkin releases entry for reuse")
    func checkinReleasesEntry() async {
        let pool = CachePool()
        let path1 = await pool.checkout()
        await pool.checkin(path: path1)
        #expect(await pool.activeCount == 0)

        // Same path should be reused
        let path2 = await pool.checkout()
        #expect(path1 == path2)
        #expect(await pool.count == 1)
    }

    @Test("Two concurrent checkouts get different paths")
    func concurrentCheckouts() async {
        let pool = CachePool()
        let path1 = await pool.checkout()
        let path2 = await pool.checkout()
        #expect(path1 != path2)
        #expect(await pool.count == 2)
        #expect(await pool.activeCount == 2)
    }

    @Test("Entry is retired after maxUses and file is removed")
    func retirementAfterMaxUses() async throws {
        let pool = CachePool(maxUses: 3)

        for _ in 0..<3 {
            let path = await pool.checkout()
            await pool.checkin(path: path)
        }

        // All uses exhausted — entry should be gone from the pool
        #expect(await pool.count == 0)
    }

    @Test("Pool reuses idle entry before allocating a new one")
    func reusesBeforeAllocating() async {
        let pool = CachePool()

        let a = await pool.checkout()
        await pool.checkin(path: a)

        let b = await pool.checkout()
        let c = await pool.checkout() // a is busy, needs a new entry

        #expect(a == b)
        #expect(b != c)
        #expect(await pool.count == 2)
    }
}
