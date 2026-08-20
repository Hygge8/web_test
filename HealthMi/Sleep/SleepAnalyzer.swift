import Foundation

/// HealthKit 睡眠分类在分析层的轻量表示，避免让算法依赖 HealthKit。
enum SleepStageKind: String, CaseIterable, Sendable, Hashable {
    case inBed
    case awake
    case core
    case deep
    case rem
    case asleepUnspecified

    var isAsleep: Bool {
        switch self {
        case .core, .deep, .rem, .asleepUnspecified: return true
        case .inBed, .awake: return false
        }
    }
}

/// 一段原始睡眠分类样本。由 HealthKit 适配器生成，也可直接用于单元测试。
struct SleepSampleInterval: Identifiable, Sendable, Hashable {
    let id: String
    let startAt: Date
    let endAt: Date
    let stage: SleepStageKind
    let sourceScore: Int?
    let isNap: Bool

    init(
        id: String,
        startAt: Date,
        endAt: Date,
        stage: SleepStageKind,
        sourceScore: Int? = nil,
        isNap: Bool = false
    ) {
        self.id = id
        self.startAt = startAt
        self.endAt = endAt
        self.stage = stage
        self.sourceScore = sourceScore
        self.isNap = isNap
    }
}

/// 单晚睡眠分析结果。日期按起床日归属。
struct SleepNight: Identifiable, Sendable, Hashable {
    let id: String
    let wakeDate: Date
    let inBedStart: Date
    let sleepOnset: Date
    let wakeTime: Date
    let inBedMinutes: Double
    let asleepMinutes: Double
    let awakeMinutes: Double
    let coreMinutes: Double
    let deepMinutes: Double
    let remMinutes: Double
    let unspecifiedMinutes: Double
    let unclassifiedMinutes: Double
    let efficiency: Double
    let awakenings: Int
    let stageCoverage: Double
    let sourceScore: Int?
    let derivedScore: Int

    var stageRows: [(stage: SleepStageKind, minutes: Double)] {
        [
            (.core, coreMinutes),
            (.deep, deepMinutes),
            (.rem, remMinutes),
            (.asleepUnspecified, unspecifiedMinutes),
            (.awake, awakeMinutes),
        ].filter { $0.minutes > 0 }
    }
}

enum SleepInsightTone: String, Sendable, Hashable {
    case positive
    case attention
    case neutral
}

struct SleepInsight: Identifiable, Sendable, Hashable {
    let title: String
    let detail: String
    let tone: SleepInsightTone

    var id: String { "\(title)|\(detail)" }
}

/// 最近一段时间的睡眠模式报告。
struct SleepPatternReport: Sendable, Hashable {
    let windowStart: Date
    let windowEnd: Date
    let targetMinutes: Double
    let nights: [SleepNight]
    let overallScore: Int
    let averageAsleepMinutes: Double
    let averageInBedMinutes: Double
    let averageEfficiency: Double
    let averageBedtimeMinute: Double
    let averageWakeMinute: Double
    let bedtimeDeviationMinutes: Double?
    let wakeTimeDeviationMinutes: Double?
    let durationDeviationMinutes: Double?
    let regularityScore: Int?
    let averageAwakenings: Double
    let deepRatio: Double
    let remRatio: Double
    let coreRatio: Double
    let recentDurationChangeMinutes: Double?
    let insights: [SleepInsight]

    var latestNight: SleepNight? { nights.last }

    var scoreLabel: String {
        switch overallScore {
        case 85...: return "稳定"
        case 70..<85: return "良好"
        case 55..<70: return "有波动"
        default: return "需关注"
        }
    }

    var regularityLabel: String {
        guard let regularityScore else { return "数据不足" }
        switch regularityScore {
        case 85...: return "很规律"
        case 70..<85: return "较规律"
        case 50..<70: return "有波动"
        default: return "波动较大"
        }
    }

    var confidenceLabel: String {
        switch nights.count {
        case 14...: return "数据充分"
        case 7..<14: return "数据一般"
        default: return "数据较少"
        }
    }
}

/// 写入 HealthKit 的自定义元数据键。旧数据没有这些字段时，分析仍可正常工作。
enum HealthMiMetadataKey {
    static let sleepScore = "com.healthmi.sleep.score"
    static let isNap = "com.healthmi.sleep.isNap"
}

/// 纯 Foundation 睡眠模式分析器。
///
/// 算法先按 `inBed` 会话切分；若数据源没有 `inBed`，则把间隔不超过 90 分钟的
/// 分期样本合并为一次睡眠。分期通过时间轴扫描去重，因此重复或重叠样本不会被双计。
enum SleepAnalyzer {
    private struct TimelineSlice {
        let start: Date
        let end: Date
        let stage: SleepStageKind

        var minutes: Double { end.timeIntervalSince(start) / 60 }
    }

    static func analyze(
        samples: [SleepSampleInterval],
        days: Int = 30,
        targetMinutes: Double = 480,
        calendar: Calendar = .current,
        now: Date = Date()
    ) -> SleepPatternReport? {
        guard days > 0, targetMinutes > 0 else { return nil }

        let today = calendar.startOfDay(for: now)
        let windowStart = calendar.date(byAdding: .day, value: -(days - 1), to: today) ?? today
        let queryStart = calendar.date(byAdding: .day, value: -1, to: windowStart) ?? windowStart

        var seen = Set<String>()
        let valid = samples
            .filter {
                $0.endAt > $0.startAt
                    && $0.endAt >= queryStart
                    && $0.startAt <= now
                    && $0.endAt.timeIntervalSince($0.startAt) <= 20 * 60 * 60
            }
            .filter { sample in
                let key = "\(sample.stage.rawValue)|\(sample.startAt.timeIntervalSince1970)|\(sample.endAt.timeIntervalSince1970)"
                return seen.insert(key).inserted
            }

        let stageSamples = valid.filter { $0.stage != .inBed }
        var boundaries = valid.filter {
            $0.stage == .inBed
                && !$0.isNap
                && $0.endAt.timeIntervalSince($0.startAt) >= 90 * 60
        }

        if boundaries.isEmpty {
            boundaries = synthesizedBoundaries(from: stageSamples)
        }

        let candidates = boundaries.compactMap { boundary in
            makeNight(
                boundary: boundary,
                samples: stageSamples,
                targetMinutes: targetMinutes,
                calendar: calendar
            )
        }

        // 同一起床日如果有多个会话（或重复 inBed），保留实际睡眠最长的一次。
        let grouped = Dictionary(grouping: candidates) { calendar.startOfDay(for: $0.wakeDate) }
        let nights = grouped.values
            .compactMap { group in
                group.max {
                    if $0.asleepMinutes == $1.asleepMinutes {
                        return $0.inBedMinutes < $1.inBedMinutes
                    }
                    return $0.asleepMinutes < $1.asleepMinutes
                }
            }
            .filter { $0.wakeDate >= windowStart && $0.wakeDate <= now }
            .sorted { $0.wakeTime < $1.wakeTime }

        guard !nights.isEmpty else { return nil }

        let averageAsleep = mean(nights.map(\.asleepMinutes))
        let averageInBed = mean(nights.map(\.inBedMinutes))
        let averageEfficiency = mean(nights.map(\.efficiency))
        let averageAwakenings = mean(nights.map { Double($0.awakenings) })

        let bedtimeMinutes = nights.map { clockMinute($0.sleepOnset, calendar: calendar) }
        let wakeMinutes = nights.map { clockMinute($0.wakeTime, calendar: calendar) }
        let bedtimeClock = circularStatistics(bedtimeMinutes)
        let wakeClock = circularStatistics(wakeMinutes)
        let averageBedtime = bedtimeClock.average
        let averageWake = wakeClock.average
        let bedtimeDeviation = nights.count >= 2 ? bedtimeClock.deviation : nil
        let wakeDeviation = nights.count >= 2 ? wakeClock.deviation : nil
        let durationDeviation = nights.count >= 2 ? standardDeviation(nights.map(\.asleepMinutes)) : nil

        let regularity: Int? = {
            guard let bedtimeDeviation, let wakeDeviation else { return nil }
            let combined = (bedtimeDeviation + wakeDeviation) / 2
            return Int(clamp(100 - combined / 1.2, min: 0, max: 100).rounded())
        }()

        let totalAsleep = nights.reduce(0) { $0 + $1.asleepMinutes }
        let deepRatio = ratio(nights.reduce(0) { $0 + $1.deepMinutes }, totalAsleep)
        let remRatio = ratio(nights.reduce(0) { $0 + $1.remMinutes }, totalAsleep)
        let coreRatio = ratio(
            nights.reduce(0) { $0 + $1.coreMinutes + $1.unspecifiedMinutes },
            totalAsleep
        )

        let dailyScore = mean(nights.map { Double($0.derivedScore) })
        let overallScore: Int
        if let regularity {
            overallScore = Int(clamp(dailyScore * 0.75 + Double(regularity) * 0.25, min: 0, max: 100).rounded())
        } else {
            overallScore = Int(clamp(dailyScore, min: 0, max: 100).rounded())
        }

        let recentChange = durationChange(nights)
        let insights = buildInsights(
            nights: nights,
            averageAsleep: averageAsleep,
            targetMinutes: targetMinutes,
            averageEfficiency: averageEfficiency,
            averageAwakenings: averageAwakenings,
            bedtimeDeviation: bedtimeDeviation,
            recentChange: recentChange
        )

        return SleepPatternReport(
            windowStart: windowStart,
            windowEnd: now,
            targetMinutes: targetMinutes,
            nights: nights,
            overallScore: overallScore,
            averageAsleepMinutes: averageAsleep,
            averageInBedMinutes: averageInBed,
            averageEfficiency: averageEfficiency,
            averageBedtimeMinute: averageBedtime,
            averageWakeMinute: averageWake,
            bedtimeDeviationMinutes: bedtimeDeviation,
            wakeTimeDeviationMinutes: wakeDeviation,
            durationDeviationMinutes: durationDeviation,
            regularityScore: regularity,
            averageAwakenings: averageAwakenings,
            deepRatio: deepRatio,
            remRatio: remRatio,
            coreRatio: coreRatio,
            recentDurationChangeMinutes: recentChange,
            insights: insights
        )
    }

    private static func synthesizedBoundaries(
        from stageSamples: [SleepSampleInterval]
    ) -> [SleepSampleInterval] {
        let ordered = stageSamples
            .filter { $0.stage.isAsleep || $0.stage == .awake }
            .sorted { $0.startAt < $1.startAt }
        guard let first = ordered.first else { return [] }

        var results: [SleepSampleInterval] = []
        var start = first.startAt
        var end = first.endAt
        var score = first.sourceScore

        for sample in ordered.dropFirst() {
            if sample.startAt.timeIntervalSince(end) <= 90 * 60 {
                end = max(end, sample.endAt)
                score = score ?? sample.sourceScore
            } else {
                results.append(syntheticBoundary(start: start, end: end, score: score))
                start = sample.startAt
                end = sample.endAt
                score = sample.sourceScore
            }
        }
        results.append(syntheticBoundary(start: start, end: end, score: score))
        return results
    }

    private static func syntheticBoundary(start: Date, end: Date, score: Int?) -> SleepSampleInterval {
        SleepSampleInterval(
            id: "synthetic_\(Int(start.timeIntervalSince1970))_\(Int(end.timeIntervalSince1970))",
            startAt: start,
            endAt: end,
            stage: .inBed,
            sourceScore: score
        )
    }

    private static func makeNight(
        boundary: SleepSampleInterval,
        samples: [SleepSampleInterval],
        targetMinutes: Double,
        calendar: Calendar
    ) -> SleepNight? {
        let relevant = samples.filter {
            $0.endAt > boundary.startAt && $0.startAt < boundary.endAt
        }
        let slices = timelineSlices(
            samples: relevant,
            start: boundary.startAt,
            end: boundary.endAt
        )

        let asleepSlices = slices.filter { $0.stage.isAsleep }
        guard let firstAsleep = asleepSlices.first?.start,
              let lastAsleep = asleepSlices.last?.end
        else { return nil }

        let asleep = asleepSlices.reduce(0) { $0 + $1.minutes }
        // 排除明显小睡；标记为 nap 的边界已在上层过滤，这里兼容旧数据。
        guard asleep >= 90 else { return nil }

        func minutes(_ stage: SleepStageKind) -> Double {
            slices.filter { $0.stage == stage }.reduce(0) { $0 + $1.minutes }
        }

        let inBed = boundary.endAt.timeIntervalSince(boundary.startAt) / 60
        let awake = minutes(.awake)
        let core = minutes(.core)
        let deep = minutes(.deep)
        let rem = minutes(.rem)
        let unspecified = minutes(.asleepUnspecified)
        let scored = awake + asleep
        let unclassified = max(0, inBed - scored)
        let efficiency = clamp(asleep / max(inBed, 1), min: 0, max: 1)
        let stageCoverage = clamp(scored / max(inBed, 1), min: 0, max: 1)

        let awakenings = slices.filter { slice in
            slice.stage == .awake
                && slice.minutes >= 2
                && slice.start.timeIntervalSince(firstAsleep) >= 10 * 60
                && lastAsleep.timeIntervalSince(slice.end) >= 10 * 60
        }.count

        let derivedScore = scoreNight(
            asleepMinutes: asleep,
            targetMinutes: targetMinutes,
            efficiency: efficiency,
            awakeMinutes: awake,
            awakenings: awakenings
        )

        return SleepNight(
            id: "\(Int(boundary.startAt.timeIntervalSince1970))_\(Int(boundary.endAt.timeIntervalSince1970))",
            wakeDate: calendar.startOfDay(for: boundary.endAt),
            inBedStart: boundary.startAt,
            sleepOnset: firstAsleep,
            wakeTime: boundary.endAt,
            inBedMinutes: inBed,
            asleepMinutes: asleep,
            awakeMinutes: awake,
            coreMinutes: core,
            deepMinutes: deep,
            remMinutes: rem,
            unspecifiedMinutes: unspecified,
            unclassifiedMinutes: unclassified,
            efficiency: efficiency,
            awakenings: awakenings,
            stageCoverage: stageCoverage,
            sourceScore: boundary.sourceScore,
            derivedScore: derivedScore
        )
    }

    /// 用相邻时间边界做扫描，同一时段只归到一个阶段，解决重复/重叠样本双计问题。
    private static func timelineSlices(
        samples: [SleepSampleInterval], start: Date, end: Date
    ) -> [TimelineSlice] {
        var points = [start, end]
        for sample in samples {
            let clippedStart = max(start, sample.startAt)
            let clippedEnd = min(end, sample.endAt)
            guard clippedEnd > clippedStart else { continue }
            points.append(clippedStart)
            points.append(clippedEnd)
        }
        points = Array(Set(points)).sorted()

        var slices: [TimelineSlice] = []
        for index in 0..<(max(0, points.count - 1)) {
            let sliceStart = points[index]
            let sliceEnd = points[index + 1]
            guard sliceEnd > sliceStart else { continue }
            let midpoint = sliceStart.addingTimeInterval(sliceEnd.timeIntervalSince(sliceStart) / 2)
            let active = samples.filter {
                $0.startAt <= midpoint && $0.endAt >= midpoint && $0.stage != .inBed
            }
            guard let selected = active.max(by: { priority($0.stage) < priority($1.stage) }) else {
                continue
            }

            if let last = slices.last, last.stage == selected.stage, last.end == sliceStart {
                slices[slices.count - 1] = TimelineSlice(
                    start: last.start, end: sliceEnd, stage: selected.stage
                )
            } else {
                slices.append(TimelineSlice(start: sliceStart, end: sliceEnd, stage: selected.stage))
            }
        }
        return slices
    }

    private static func priority(_ stage: SleepStageKind) -> Int {
        switch stage {
        case .awake: return 6
        case .deep: return 5
        case .rem: return 4
        case .core: return 3
        case .asleepUnspecified: return 2
        case .inBed: return 1
        }
    }

    private static func scoreNight(
        asleepMinutes: Double,
        targetMinutes: Double,
        efficiency: Double,
        awakeMinutes: Double,
        awakenings: Int
    ) -> Int {
        let durationDelta = abs(asleepMinutes - targetMinutes)
        let durationScore = clamp(100 - durationDelta / 1.8, min: 0, max: 100)
        let efficiencyScore = clamp((efficiency - 0.65) / 0.25 * 100, min: 0, max: 100)
        let continuityScore = clamp(
            100 - Double(awakenings) * 12 - awakeMinutes * 0.35,
            min: 0,
            max: 100
        )
        return Int((durationScore * 0.5 + efficiencyScore * 0.3 + continuityScore * 0.2).rounded())
    }

    private static func durationChange(_ nights: [SleepNight]) -> Double? {
        guard nights.count >= 4 else { return nil }
        let comparisonCount = min(3, nights.count / 2)
        let recent = nights.suffix(comparisonCount).map(\.asleepMinutes)
        let previousStart = nights.count - comparisonCount * 2
        let previousEnd = nights.count - comparisonCount
        let previous = nights[previousStart..<previousEnd].map(\.asleepMinutes)
        return mean(recent) - mean(previous)
    }

    private static func buildInsights(
        nights: [SleepNight],
        averageAsleep: Double,
        targetMinutes: Double,
        averageEfficiency: Double,
        averageAwakenings: Double,
        bedtimeDeviation: Double?,
        recentChange: Double?
    ) -> [SleepInsight] {
        var insights: [SleepInsight] = []

        if nights.count < 7 {
            insights.append(SleepInsight(
                title: "先积累更多夜晚",
                detail: "目前只有 \(nights.count) 晚有效数据；连续记录至少 7 晚后，规律性判断会更可靠。",
                tone: .neutral
            ))
        }

        let durationGap = targetMinutes - averageAsleep
        if durationGap >= 30 {
            insights.append(SleepInsight(
                title: "平均时长低于目标",
                detail: "近期平均每晚比目标少约 \(Int(durationGap.rounded())) 分钟，可先尝试把上床时间提前 15–30 分钟。",
                tone: .attention
            ))
        } else if durationGap <= -60 {
            insights.append(SleepInsight(
                title: "平均时长高于目标",
                detail: "平均每晚比当前目标多约 \(Int(abs(durationGap).rounded())) 分钟；如果醒后仍疲惫，可结合连续趋势观察。",
                tone: .neutral
            ))
        } else {
            insights.append(SleepInsight(
                title: "睡眠时长接近目标",
                detail: "平均时长与设定目标相差不到 30 分钟，继续维持当前节奏。",
                tone: .positive
            ))
        }

        if averageEfficiency < 0.85 {
            insights.append(SleepInsight(
                title: "卧床与睡着时间差距较大",
                detail: "记录到的平均睡眠效率为 \(Int((averageEfficiency * 100).rounded()))%。可优先保持固定起床时间，并减少临睡前长时间清醒。",
                tone: .attention
            ))
        }

        if let bedtimeDeviation, bedtimeDeviation > 60 {
            insights.append(SleepInsight(
                title: "入睡时间波动较大",
                detail: "入睡时间的典型波动约 \(Int(bedtimeDeviation.rounded())) 分钟；先把每日波动控制在 1 小时内更容易形成稳定模式。",
                tone: .attention
            ))
        } else if let bedtimeDeviation, bedtimeDeviation <= 30, nights.count >= 7 {
            insights.append(SleepInsight(
                title: "入睡时间较稳定",
                detail: "入睡时间的典型波动约 \(Int(bedtimeDeviation.rounded())) 分钟，作息规律性表现良好。",
                tone: .positive
            ))
        }

        if averageAwakenings >= 2 {
            insights.append(SleepInsight(
                title: "夜间清醒偏多",
                detail: "平均每晚记录到 \(String(format: "%.1f", averageAwakenings)) 次持续 2 分钟以上的中途清醒，可结合噪声、光线和睡前饮食观察诱因。",
                tone: .attention
            ))
        }

        if let recentChange, abs(recentChange) >= 30 {
            let direction = recentChange > 0 ? "增加" : "减少"
            insights.append(SleepInsight(
                title: "近期时长有变化",
                detail: "最近 3 晚较之前 3 晚平均每晚\(direction)约 \(Int(abs(recentChange).rounded())) 分钟。",
                tone: recentChange > 0 ? .positive : .attention
            ))
        }

        return Array(insights.prefix(5))
    }

    private static func clockMinute(_ date: Date, calendar: Calendar) -> Double {
        let components = calendar.dateComponents([.hour, .minute, .second], from: date)
        return Double((components.hour ?? 0) * 60 + (components.minute ?? 0))
            + Double(components.second ?? 0) / 60
    }

    /// 圆周均值与标准差，避免 23:50 和 00:10 被误判为相差近一天。
    private static func circularStatistics(_ values: [Double]) -> (average: Double, deviation: Double) {
        guard !values.isEmpty else { return (0, 0) }
        let circle = 24.0 * 60.0
        let angles = values.map { $0 / circle * 2 * Double.pi }
        let averageSin = mean(angles.map { sin($0) })
        let averageCos = mean(angles.map { cos($0) })
        var angle = atan2(averageSin, averageCos)
        if angle < 0 { angle += 2 * Double.pi }
        let average = angle / (2 * Double.pi) * circle
        let squaredDistances = values.map { value -> Double in
            let direct = abs(value - average)
            let distance = min(direct, circle - direct)
            return distance * distance
        }
        return (average, sqrt(mean(squaredDistances)))
    }

    private static func mean(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0 }
        return values.reduce(0, +) / Double(values.count)
    }

    private static func standardDeviation(_ values: [Double]) -> Double {
        guard values.count >= 2 else { return 0 }
        let average = mean(values)
        let variance = values.reduce(0) { $0 + pow($1 - average, 2) } / Double(values.count)
        return sqrt(variance)
    }

    private static func ratio(_ numerator: Double, _ denominator: Double) -> Double {
        guard denominator > 0 else { return 0 }
        return clamp(numerator / denominator, min: 0, max: 1)
    }

    private static func clamp(_ value: Double, min lower: Double, max upper: Double) -> Double {
        Swift.min(Swift.max(value, lower), upper)
    }
}
