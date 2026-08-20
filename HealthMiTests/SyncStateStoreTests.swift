import SwiftData
import XCTest
@testable import HealthMi

@MainActor
final class SyncStateStoreTests: XCTestCase {
    // XCTest 的同步 `setUp()` 是 nonisolated，Swift 6 下不能在其中修改
    // `@MainActor` 的 SwiftData 状态。每个测试实例用惰性属性创建独立内存容器。
    private lazy var container: ModelContainer = {
        let schema = Schema([SyncState.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try! ModelContainer(for: schema, configurations: [config])
    }()
    private lazy var context: ModelContext = container.mainContext

    func testRecordUpdatesState() {
        let type: SyncDataType = .heartRate
        let highWater = Date()
        SyncStateStore.record(type: type, highWater: highWater, added: 42, in: context)

        let state = SyncStateStore.state(for: type, in: context)
        XCTAssertNotNil(state)
        XCTAssertEqual(state?.lastSyncedEnd?.timeIntervalSince(highWater) ?? -1, 0, accuracy: 1)
        XCTAssertEqual(state?.lastAddedCount, 42)
    }

    func testClearAllRemovesAllStates() {
        SyncStateStore.record(type: .heartRate, highWater: Date(), added: 10, in: context)
        SyncStateStore.record(type: .sleep, highWater: Date(), added: 5, in: context)
        SyncStateStore.record(type: .spo2, highWater: Date(), added: 3, in: context)

        SyncStateStore.clearAll(in: context)

        for type in SyncDataType.allCases {
            XCTAssertNil(SyncStateStore.state(for: type, in: context))
        }
    }

    func testRecordTwiceUpdatesSameRow() {
        let type: SyncDataType = .heartRate
        SyncStateStore.record(type: type, highWater: Date(timeIntervalSinceNow: -3600), added: 10, in: context)
        SyncStateStore.record(type: type, highWater: Date(), added: 20, in: context)

        let state = SyncStateStore.state(for: type, in: context)
        XCTAssertEqual(state?.lastAddedCount, 20)
    }
}
