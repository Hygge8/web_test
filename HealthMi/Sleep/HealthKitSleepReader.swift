import Foundation
import HealthKit

/// 从 HealthKit 读取睡眠分类样本，并交给纯算法层生成模式报告。
enum HealthKitSleepReader {
    static func report(
        days: Int = 30,
        targetMinutes: Double = 480,
        now: Date = Date()
    ) async -> SleepPatternReport? {
        guard HealthKitManager.isAvailable, days > 0 else { return nil }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)
        let start = calendar.date(byAdding: .day, value: -days, to: today) ?? today
        let predicate = HKQuery.predicateForSamples(
            withStart: start,
            end: now,
            options: []
        )

        guard let samples = try? await query(predicate: predicate) else { return nil }
        let intervals = samples.compactMap(mapSample)

        // HealthKit 可能同时包含 Apple Watch 和小米写入的重叠睡眠。
        // 只要找到了 HealthMi 样本，就使用同一来源，避免跨来源重复统计；
        // 否则仍可分析用户已有的 Apple 健康睡眠数据。
        let healthMiIntervals = intervals.filter { $0.id.hasPrefix("mi_fitness_sleep_") }
        let selected = healthMiIntervals.isEmpty ? intervals : healthMiIntervals

        return SleepAnalyzer.analyze(
            samples: selected,
            days: days,
            targetMinutes: targetMinutes,
            calendar: calendar,
            now: now
        )
    }

    private static func mapSample(_ sample: HKCategorySample) -> SleepSampleInterval? {
        guard let stage = mapStage(sample.value), sample.endDate > sample.startDate else {
            return nil
        }

        let externalID = sample.metadata?[HKMetadataKeyExternalUUID] as? String
        let fallbackID = "healthkit_sleep_\(stage.rawValue)_\(Int(sample.startDate.timeIntervalSince1970))_\(Int(sample.endDate.timeIntervalSince1970))"
        let score = integerMetadata(sample.metadata?[HealthMiMetadataKey.sleepScore])
        let isNap = booleanMetadata(sample.metadata?[HealthMiMetadataKey.isNap]) ?? false

        return SleepSampleInterval(
            id: externalID ?? fallbackID,
            startAt: sample.startDate,
            endAt: sample.endDate,
            stage: stage,
            sourceScore: score,
            isNap: isNap
        )
    }

    private static func mapStage(_ value: Int) -> SleepStageKind? {
        if value == HKCategoryValueSleepAnalysis.inBed.rawValue { return .inBed }
        if value == HKCategoryValueSleepAnalysis.awake.rawValue { return .awake }
        if value == HKCategoryValueSleepAnalysis.asleepCore.rawValue { return .core }
        if value == HKCategoryValueSleepAnalysis.asleepDeep.rawValue { return .deep }
        if value == HKCategoryValueSleepAnalysis.asleepREM.rawValue { return .rem }
        if value == HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue {
            return .asleepUnspecified
        }
        return nil
    }

    private static func integerMetadata(_ value: Any?) -> Int? {
        if let number = value as? NSNumber { return number.intValue }
        if let integer = value as? Int { return integer }
        if let string = value as? String { return Int(string) }
        return nil
    }

    private static func booleanMetadata(_ value: Any?) -> Bool? {
        if let number = value as? NSNumber { return number.boolValue }
        if let boolean = value as? Bool { return boolean }
        if let string = value as? String {
            return ["true", "1", "yes"].contains(string.lowercased())
        }
        return nil
    }

    private static func query(predicate: NSPredicate) async throws -> [HKCategorySample] {
        try await withCheckedThrowingContinuation {
            (continuation: CheckedContinuation<[HKCategorySample], Error>) in
            let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
            let query = HKSampleQuery(
                sampleType: HKCategoryType(.sleepAnalysis),
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sort]
            ) { _, samples, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: samples?.compactMap { $0 as? HKCategorySample } ?? [])
                }
            }
            HealthKitManager.healthStore.execute(query)
        }
    }
}
