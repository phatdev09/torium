import Foundation

public enum WorkerMode: String {
    case eco = "eco"     // Mode 1: 3-5 concurrent workers, cool device, battery-friendly
    case turbo = "turbo" // Mode 2: Maximum concurrent tasks, no limit
}

/// Manages concurrent worker throttling to protect iPhone 6s A9 hardware from overheating and Jetsam crashes
public final class WorkerPoolManager {
    public static let shared = WorkerPoolManager()

    public private(set) var currentMode: WorkerMode = .eco
    public private(set) var maxConcurrentWorkers: Int = 3

    private var activeWorkerCount: Int = 0
    private let lock = NSLock()

    private init() {
        reloadSettings()
    }

    public func reloadSettings() {
        lock.lock()
        defer { lock.unlock() }

        let modeStr = DatabaseManager.shared.getSetting(key: "worker_mode") ?? "eco"
        currentMode = WorkerMode(rawValue: modeStr) ?? .eco

        let maxStr = DatabaseManager.shared.getSetting(key: "max_concurrent_workers") ?? "3"
        maxConcurrentWorkers = max(1, min(30, Int(maxStr) ?? 3))
    }

    public func setMaxWorkers(_ count: Int) {
        lock.lock()
        maxConcurrentWorkers = max(1, min(30, count))
        DatabaseManager.shared.setSetting(key: "max_concurrent_workers", value: "\(maxConcurrentWorkers)")
        lock.unlock()
    }

    public func setMode(_ mode: WorkerMode) {
        lock.lock()
        currentMode = mode
        DatabaseManager.shared.setSetting(key: "worker_mode", value: mode.rawValue)
        lock.unlock()

        DatabaseManager.shared.insertLog(Log(
            level: .info,
            action: .general,
            message: "Hệ thống chuyển sang chế độ: \(mode == .eco ? "🟢 An Toàn (Eco - Tối đa \(maxConcurrentWorkers) workers)" : "🚀 Turbo (Tối đa tốc độ)")"
        ))
    }

    /// Checks if a new worker can be spawned immediately
    public func canSpawnWorker() -> Bool {
        lock.lock()
        defer { lock.unlock() }

        if currentMode == .turbo {
            return true
        }
        return activeWorkerCount < maxConcurrentWorkers
    }

    /// Acquires a worker slot. If in Eco mode and limit is reached, suspends until a slot frees up.
    public func acquireWorkerSlot() async {
        if currentMode == .turbo {
            lock.lock()
            activeWorkerCount += 1
            lock.unlock()
            return
        }

        while true {
            lock.lock()
            if activeWorkerCount < maxConcurrentWorkers {
                activeWorkerCount += 1
                lock.unlock()
                return
            }
            lock.unlock()
            // Wait 500ms and check slot availability again
            try? await Task.sleep(nanoseconds: 500_000_000)
        }
    }

    /// Releases an acquired worker slot
    public func releaseWorkerSlot() {
        lock.lock()
        activeWorkerCount = max(0, activeWorkerCount - 1)
        lock.unlock()
    }

    public var activeWorkers: Int {
        lock.lock()
        defer { lock.unlock() }
        return activeWorkerCount
    }
}
