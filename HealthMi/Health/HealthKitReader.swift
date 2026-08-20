import HealthKit
import Foundation

/// 最近一段时间的健康摘要（用于 App 内回显已同步的数据）。
struct HealthSummary: Sendable {
    var stepCount: Double?
    var sleepMinutes: Double?
    var avgHeartRate: Double?
    var avgRespiratoryRate: Double?
    var avgHRV: Double?
}

/// 单日趋势数据点（用于 Charts）。
struct DailyTrend: Identifiable, Sendable {
    let date: Date
    let stepCount: Double?
    let avgHeartRate: Double?
    let sleepMinutes: Double?
    let avgHRV: Double?

    var id: Date { date }
}

/// 从 HealthKit 读回摘要，让用户在 App 里直接看到已同步的数据。
enum HealthKitReader {
    /// 最近 7 天（含今天）的摘要。
    static func summary(days: Int = 7) async -> HealthSummary {
        let end = Date()
        let start = Calendar.current.date(byAdding: .day, value: -(days - 1), to: end) ?? end
        var summary = HealthSummary()
        summary.stepCount = try? await sum(
            .stepCount, unit: .count(), start: start, end: end
        )
        summary.avgHeartRate = try? await average(
            .heartRate, unit: .count().unitDivided(by: .minute()), start: start, end: end
        )
        summary.avgRespiratoryRate = try? await average(
            .respiratoryRate, unit: .count().unitDivided(by: .minute()), start: start, end: end
        )
        summary.avgHRV = try? await average(
            .heartRateVariabilitySDNN, unit: .secondUnit(with: .milli), start: start, end: end
        )
        summary.sleepMinutes = try? await sleepMinutes(from: start, to: end)
        return summary
    }

    // MARK: - 按天趋势序列（用于 Charts）

    /// 最近 N 天每天的步数、心率、睡眠、HRV 趋势数据。
    static func trendSeries(days: Int = 7) async -> [DailyTrend] {
        let calendar = Calendar.current
        let now = Date()
        let start = calendar.date(byAdding: .day, value: -(days - 1), to: now) ?? now
        let dayStart = calendar.startOfDay(for: start)

        // 四个查询互相独立，用 async let 并行执行
        async let stepTask = dailyCollection(
            .stepCount, unit: .count(), start: dayStart, end: now, option: .cumulativeSum
        )
        async let hrTask = dailyCollection(
            .heartRate, unit: .count().unitDivided(by: .minute()), start: dayStart, end: now, option: .discreteAverage
        )
        async let hrvTask = dailyCollection(
            .heartRateVariabilitySDNN, unit: .secondUnit(with: .milli), start: dayStart, end: now, option: .discreteAverage
        )
        async let sleepTask = dailySleep(start: dayStart, end: now)

        let sleepMap = await sleepTask
        let stepMap: [Date: Double] = (try? await stepTask) ?? [:]
        let hrMap: [Date: Double] = (try? await hrTask) ?? [:]
        let hrvMap: [Date: Double] = (try? await hrvTask) ?? [:]

        var trends: [DailyTrend] = []
        for offset in 0..<days {
            let day = calendar.date(byAdding: .day, value: offset, to: dayStart) ?? dayStart
            trends.append(DailyTrend(
                date: day,
                stepCount: stepMap[day],
                avgHeartRate: hrMap[day],
                sleepMinutes: sleepMap[day],
                avgHRV: hrvMap[day]
            ))
        }
        return trends
    }

    /// 用 HKStatisticsCollectionQuery 按天分桶查询。
    private static func dailyCollection(
        _ identifier: HKQuantityTypeIdentifier, unit: HKUnit,
        start: Date, end: Date, option: HKStatisticsOptions
    ) async throws -> [Date: Double] {
        let calendar = Calendar.current
        let anchor = calendar.startOfDay(for: start)
        var result: [Date: Double] = [:]
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let predicate = HKQuery.predicateForSamples(withStart: start, end: end)
            let query = HKStatisticsCollectionQuery(
                quantityType: HKQuantityType(identifier),
                quantitySamplePredicate: predicate,
                options: option,
                anchorDate: anchor,
                intervalComponents: DateComponents(day: 1)
            )
            query.initialResultsHandler = { _, collection, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                collection?.enumerateStatistics(from: start, to: end) { stats, _ in
                    let value: Double?
                    if option == .cumulativeSum {
                        value = stats.sumQuantity()?.doubleValue(for: unit)
                    } else {
                        value = stats.averageQuantity()?.doubleValue(for: unit)
                    }
                    let day = calendar.startOfDay(for: stats.startDate)
                    if let value { result[day] = value }
                }
                continuation.resume()
            }
            HealthKitManager.healthStore.execute(query)
        }
        return result
    }

    /// 睡眠按起床日聚合；复用睡眠分析器以处理跨午夜和重复来源。
    private static func dailySleep(start: Date, end: Date) async -> [Date: Double] {
        let calendar = Calendar.current
        let dayDistance = calendar.dateComponents([.day], from: start, to: end).day ?? 0
        let days = max(1, dayDistance + 1)
        guard let report = await HealthKitSleepReader.report(days: days, now: end) else {
            return [:]
        }
        return Dictionary(uniqueKeysWithValues: report.nights.compactMap { night in
            let day = calendar.startOfDay(for: night.wakeDate)
            guard day >= calendar.startOfDay(for: start), day <= end else { return nil }
            return (day, night.asleepMinutes)
        })
    }

    private static func sum(
        _ identifier: HKQuantityTypeIdentifier, unit: HKUnit, start: Date, end: Date
    ) async throws -> Double? {
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end)
        let stats = try await statistics(
            for: HKQuantityType(identifier), predicate: predicate, options: .cumulativeSum
        )
        return stats.sumQuantity()?.doubleValue(for: unit)
    }

    private static func average(
        _ identifier: HKQuantityTypeIdentifier, unit: HKUnit, start: Date, end: Date
    ) async throws -> Double? {
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end)
        let stats = try await statistics(
            for: HKQuantityType(identifier), predicate: predicate, options: .discreteAverage
        )
        return stats.averageQuantity()?.doubleValue(for: unit)
    }

    /// 睡眠总时长（分钟）= asleepUnspecified / Core / Deep / REM 之和。
    private static func sleepMinutes(from start: Date, to end: Date) async throws -> Double {
        let calendar = Calendar.current
        let dayDistance = calendar.dateComponents([.day], from: start, to: end).day ?? 0
        let days = max(1, dayDistance + 1)
        guard let report = await HealthKitSleepReader.report(days: days, now: end) else {
            throw HealthKitReaderError.noStatistics
        }
        return report.nights.reduce(0) { $0 + $1.asleepMinutes }
    }

    // MARK: - 底层查询

    private static func statistics(
        for type: HKQuantityType, predicate: NSPredicate, options: HKStatisticsOptions
    ) async throws -> HKStatistics {
        try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: type,
                quantitySamplePredicate: predicate,
                options: options
            ) { _, statistics, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let statistics {
                    continuation.resume(returning: statistics)
                } else {
                    continuation.resume(throwing: HealthKitReaderError.noStatistics)
                }
            }
            HealthKitManager.healthStore.execute(query)
        }
    }

    enum HealthKitReaderError: LocalizedError {
        case noStatistics
        var errorDescription: String? { "没有可用的统计数据" }
    }
}
