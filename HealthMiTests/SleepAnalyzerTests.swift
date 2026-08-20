import XCTest
@testable import HealthMi

final class SleepAnalyzerTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    func testCrossMidnightNightComputesStagesAndEfficiency() throws {
        let start = date(day: 1, hour: 23)
        let end = date(day: 2, hour: 7)
        let samples = [
            sample("bed", start, end, .inBed, score: 91),
            sample("core1", start, date(day: 2, hour: 1), .core),
            sample("deep", date(day: 2, hour: 1), date(day: 2, hour: 3), .deep),
            sample("awake", date(day: 2, hour: 3), date(day: 2, hour: 3, minute: 10), .awake),
            sample("rem", date(day: 2, hour: 3, minute: 10), date(day: 2, hour: 4, minute: 40), .rem),
            sample("core2", date(day: 2, hour: 4, minute: 40), end, .core),
        ]

        let report = try XCTUnwrap(SleepAnalyzer.analyze(
            samples: samples,
            days: 7,
            targetMinutes: 480,
            calendar: calendar,
            now: date(day: 3, hour: 12)
        ))
        let night = try XCTUnwrap(report.nights.first)

        XCTAssertEqual(night.wakeDate, date(day: 2, hour: 0))
        XCTAssertEqual(night.asleepMinutes, 470, accuracy: 0.01)
        XCTAssertEqual(night.awakeMinutes, 10, accuracy: 0.01)
        XCTAssertEqual(night.coreMinutes, 260, accuracy: 0.01)
        XCTAssertEqual(night.deepMinutes, 120, accuracy: 0.01)
        XCTAssertEqual(night.remMinutes, 90, accuracy: 0.01)
        XCTAssertEqual(night.efficiency, 470.0 / 480.0, accuracy: 0.001)
        XCTAssertEqual(night.awakenings, 1)
        XCTAssertEqual(night.sourceScore, 91)
    }

    func testOverlappingSamplesAreNotDoubleCounted() throws {
        let start = date(day: 1, hour: 23)
        let end = date(day: 2, hour: 7)
        let samples = [
            sample("bed", start, end, .inBed),
            sample("core-a", start, end, .core),
            sample("core-b", start, end, .core),
            sample("deep", date(day: 2, hour: 1), date(day: 2, hour: 3), .deep),
        ]

        let report = try XCTUnwrap(SleepAnalyzer.analyze(
            samples: samples,
            days: 7,
            calendar: calendar,
            now: date(day: 3, hour: 12)
        ))
        let night = try XCTUnwrap(report.nights.first)

        XCTAssertEqual(night.asleepMinutes, 480, accuracy: 0.01)
        XCTAssertEqual(night.deepMinutes, 120, accuracy: 0.01)
        XCTAssertEqual(night.coreMinutes, 360, accuracy: 0.01)
    }

    func testIrregularBedtimesProduceLowerRegularityScore() throws {
        let stable = makeNights(normalizedBedMinutes: Array(repeating: 23 * 60, count: 6))
        let irregular = makeNights(normalizedBedMinutes: [20 * 60, 26 * 60, 22 * 60, 27 * 60, 21 * 60, 25 * 60])
        let now = date(day: 10, hour: 12)

        let stableReport = try XCTUnwrap(SleepAnalyzer.analyze(
            samples: stable,
            days: 14,
            calendar: calendar,
            now: now
        ))
        let irregularReport = try XCTUnwrap(SleepAnalyzer.analyze(
            samples: irregular,
            days: 14,
            calendar: calendar,
            now: now
        ))

        XCTAssertGreaterThan(
            try XCTUnwrap(stableReport.regularityScore),
            try XCTUnwrap(irregularReport.regularityScore)
        )
        XCTAssertLessThan(stableReport.bedtimeDeviationMinutes ?? .infinity, 1)
        XCTAssertGreaterThan(irregularReport.bedtimeDeviationMinutes ?? 0, 60)
    }

    func testNapFlaggedSessionIsExcluded() throws {
        let mainStart = date(day: 1, hour: 23)
        let mainEnd = date(day: 2, hour: 7)
        let napStart = date(day: 2, hour: 13)
        let napEnd = date(day: 2, hour: 15)
        let samples = [
            sample("main-bed", mainStart, mainEnd, .inBed),
            sample("main-core", mainStart, mainEnd, .core),
            sample("nap-bed", napStart, napEnd, .inBed, isNap: true),
            sample("nap-core", napStart, napEnd, .core),
        ]

        let report = try XCTUnwrap(SleepAnalyzer.analyze(
            samples: samples,
            days: 7,
            calendar: calendar,
            now: date(day: 3, hour: 12)
        ))

        XCTAssertEqual(report.nights.count, 1)
        XCTAssertEqual(report.nights.first?.asleepMinutes, 480)
    }

    private func makeNights(normalizedBedMinutes: [Int]) -> [SleepSampleInterval] {
        var samples: [SleepSampleInterval] = []
        for (offset, minute) in normalizedBedMinutes.enumerated() {
            let dayStart = date(day: 1 + offset, hour: 0)
            let start = calendar.date(byAdding: .minute, value: minute, to: dayStart)!
            let end = calendar.date(byAdding: .hour, value: 8, to: start)!
            samples.append(sample("bed-\(offset)", start, end, .inBed))
            samples.append(sample("core-\(offset)", start, end, .core))
        }
        return samples
    }

    private func sample(
        _ id: String,
        _ start: Date,
        _ end: Date,
        _ stage: SleepStageKind,
        score: Int? = nil,
        isNap: Bool = false
    ) -> SleepSampleInterval {
        SleepSampleInterval(
            id: id,
            startAt: start,
            endAt: end,
            stage: stage,
            sourceScore: score,
            isNap: isNap
        )
    }

    private func date(day: Int, hour: Int, minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(
            year: 2026,
            month: 1,
            day: day,
            hour: hour,
            minute: minute
        ))!
    }
}
