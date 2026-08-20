import Charts
import SwiftUI

/// 30 天睡眠模式分析：时长、规律性、效率、分期结构和趋势提示。
struct SleepAnalysisView: View {
    @Environment(AppModel.self) private var model
    @AppStorage("sleep_target_hours") private var targetHours = 8.0

    private let targetOptions = stride(from: 6.0, through: 10.0, by: 0.5).map { $0 }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                targetPicker

                if model.isLoadingSleepAnalysis && model.sleepReport == nil {
                    ProgressView("正在分析最近 30 天…")
                        .frame(maxWidth: .infinity, minHeight: 240)
                } else if let report = model.sleepReport {
                    scoreCard(report)
                    metricsGrid(report)
                    durationChart(report)
                    stageCard(report)
                    insightCard(report)
                    recentNightsCard(report)
                    methodologyCard(report)
                } else {
                    ContentUnavailableView {
                        Label("暂无睡眠数据", systemImage: "moon.zzz")
                    } description: {
                        Text("请先授权 Apple 健康并同步“小米睡眠”。至少一晚含分期的数据即可生成报告。")
                    } actions: {
                        Button("重新读取") {
                            Task { await refresh() }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .frame(minHeight: 360)
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("睡眠模式")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: targetHours) { await refresh() }
        .refreshable { await refresh() }
    }

    private var targetPicker: some View {
        HStack {
            Label("每晚目标", systemImage: "target")
                .font(.subheadline.weight(.medium))
            Spacer()
            Picker("每晚目标", selection: $targetHours) {
                ForEach(targetOptions, id: \.self) { hours in
                    Text(hours.formatted(.number.precision(.fractionLength(hours.rounded() == hours ? 0 : 1))) + " 小时")
                        .tag(hours)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
        }
        .padding()
        .background(.background, in: RoundedRectangle(cornerRadius: 16))
    }

    private func scoreCard(_ report: SleepPatternReport) -> some View {
        HStack(spacing: 20) {
            ZStack {
                Circle()
                    .stroke(.white.opacity(0.22), lineWidth: 10)
                Circle()
                    .trim(from: 0, to: Double(report.overallScore) / 100)
                    .stroke(.white, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                VStack(spacing: 0) {
                    Text("\(report.overallScore)")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                    Text("趋势分")
                        .font(.caption2)
                        .opacity(0.85)
                }
            }
            .frame(width: 116, height: 116)

            VStack(alignment: .leading, spacing: 7) {
                Text(report.scoreLabel)
                    .font(.title2.bold())
                Text("基于最近 \(report.nights.count) 晚")
                    .font(.subheadline)
                    .opacity(0.85)
                if let latest = report.latestNight {
                    Text("昨夜 \(Self.duration(latest.asleepMinutes)) · 效率 \(Self.percent(latest.efficiency))")
                        .font(.caption)
                        .opacity(0.9)
                }
                Label(report.confidenceLabel, systemImage: "chart.bar.fill")
                    .font(.caption.weight(.medium))
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(.white.opacity(0.16), in: Capsule())
            }
            Spacer(minLength: 0)
        }
        .foregroundStyle(.white)
        .padding(20)
        .background(
            LinearGradient(
                colors: [Color.indigo, Color.blue.opacity(0.82)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 22)
        )
    }

    private func metricsGrid(_ report: SleepPatternReport) -> some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            SleepMetricCard(
                title: "平均睡眠",
                value: Self.duration(report.averageAsleepMinutes),
                detail: "目标 \(Self.duration(report.targetMinutes))",
                icon: "bed.double.fill",
                color: .indigo
            )
            SleepMetricCard(
                title: "睡眠效率",
                value: Self.percent(report.averageEfficiency),
                detail: "睡着 ÷ 卧床",
                icon: "gauge.with.dots.needle.67percent",
                color: .teal
            )
            SleepMetricCard(
                title: "平均入睡",
                value: Self.clock(report.averageBedtimeMinute),
                detail: report.bedtimeDeviationMinutes.map { "波动 ±\(Int($0.rounded())) 分" } ?? "数据不足",
                icon: "moon.fill",
                color: .purple
            )
            SleepMetricCard(
                title: "平均起床",
                value: Self.clock(report.averageWakeMinute),
                detail: report.regularityLabel,
                icon: "sunrise.fill",
                color: .orange
            )
        }
    }

    private func durationChart(_ report: SleepPatternReport) -> some View {
        let nights = Array(report.nights.suffix(14))
        let maxHours = max(10, (nights.map(\.asleepMinutes).max() ?? report.targetMinutes) / 60 + 1)
        return VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("睡眠时长趋势")
                    .font(.headline)
                Text("最近 \(nights.count) 晚；虚线为你的目标")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Chart {
                ForEach(nights) { night in
                    BarMark(
                        x: .value("日期", night.wakeDate, unit: .day),
                        y: .value("小时", night.asleepMinutes / 60)
                    )
                    .foregroundStyle(
                        night.asleepMinutes >= report.targetMinutes - 30
                            ? Color.indigo.gradient
                            : Color.blue.opacity(0.48).gradient
                    )
                    .cornerRadius(3)
                }
                RuleMark(y: .value("目标", report.targetMinutes / 60))
                    .foregroundStyle(.orange)
                    .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                    .annotation(position: .top, alignment: .trailing) {
                        Text("目标")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                    }
            }
            .chartYScale(domain: 0...maxHours)
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: nights.count > 8 ? 2 : 1)) { value in
                    AxisValueLabel(format: .dateTime.day())
                    AxisGridLine().foregroundStyle(.clear)
                }
            }
            .frame(height: 210)
        }
        .padding()
        .background(.background, in: RoundedRectangle(cornerRadius: 18))
    }

    private func stageCard(_ report: SleepPatternReport) -> some View {
        let stages = [
            SleepStageShare(stage: .core, ratio: report.coreRatio),
            SleepStageShare(stage: .deep, ratio: report.deepRatio),
            SleepStageShare(stage: .rem, ratio: report.remRatio),
        ].filter { $0.ratio > 0 }

        return VStack(alignment: .leading, spacing: 14) {
            Text("睡眠结构")
                .font(.headline)
            Text("按所有有效夜晚的已睡分期汇总")
                .font(.caption)
                .foregroundStyle(.secondary)

            GeometryReader { geometry in
                HStack(spacing: 3) {
                    ForEach(stages) { item in
                        RoundedRectangle(cornerRadius: 5)
                            .fill(item.stage.color)
                            .frame(width: max(2, geometry.size.width * item.ratio))
                    }
                }
            }
            .frame(height: 18)

            ForEach(stages) { item in
                HStack {
                    Circle()
                        .fill(item.stage.color)
                        .frame(width: 9, height: 9)
                    Text(item.stage.displayName)
                    Spacer()
                    Text(Self.percent(item.ratio))
                        .foregroundStyle(.secondary)
                }
                .font(.subheadline)
            }
        }
        .padding()
        .background(.background, in: RoundedRectangle(cornerRadius: 18))
    }

    private func insightCard(_ report: SleepPatternReport) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("模式提示", systemImage: "sparkles")
                .font(.headline)
            ForEach(report.insights) { insight in
                HStack(alignment: .top, spacing: 11) {
                    Image(systemName: insight.tone.icon)
                        .foregroundStyle(insight.tone.color)
                        .frame(width: 22)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(insight.title)
                            .font(.subheadline.weight(.semibold))
                        Text(insight.detail)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                }
            }
        }
        .padding()
        .background(.background, in: RoundedRectangle(cornerRadius: 18))
    }

    private func recentNightsCard(_ report: SleepPatternReport) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("最近夜晚")
                .font(.headline)
                .padding(.horizontal)
                .padding(.top)

            ForEach(Array(report.nights.suffix(7).reversed())) { night in
                NavigationLink {
                    SleepNightDetailView(night: night)
                } label: {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(night.wakeDate.formatted(.dateTime.month().day().weekday(.abbreviated)))
                                .font(.subheadline.weight(.medium))
                            Text("\(night.sleepOnset.formatted(date: .omitted, time: .shortened)) → \(night.wakeTime.formatted(date: .omitted, time: .shortened))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(Self.duration(night.asleepMinutes))
                                .font(.subheadline.weight(.semibold))
                            Text("趋势分 \(night.derivedScore)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Image(systemName: "chevron.right")
                            .font(.caption.bold())
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 10)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                if night.id != report.nights.first?.id {
                    Divider().padding(.leading)
                }
            }
        }
        .background(.background, in: RoundedRectangle(cornerRadius: 18))
    }

    private func methodologyCard(_ report: SleepPatternReport) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("关于趋势分", systemImage: "info.circle")
                .font(.subheadline.weight(.semibold))
            Text("趋势分综合睡眠时长、效率、夜间清醒和作息规律性；睡眠分期仅展示占比，不参与医学判断。分析基于 Apple 健康中的睡眠记录，不替代医生诊断。若持续出现明显不适、憋醒或呼吸异常，请咨询专业医务人员。")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Text("分析窗口：\(report.windowStart.formatted(date: .abbreviated, time: .omitted)) – \(report.windowEnd.formatted(date: .abbreviated, time: .omitted))")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding()
        .background(.background, in: RoundedRectangle(cornerRadius: 18))
    }

    private func refresh() async {
        await model.refreshSleepAnalysis(days: 30, targetHours: targetHours)
    }

    static func duration(_ minutes: Double) -> String {
        let rounded = max(0, Int(minutes.rounded()))
        let hours = rounded / 60
        let remainder = rounded % 60
        return remainder == 0 ? "\(hours) 小时" : "\(hours) 小时 \(remainder) 分"
    }

    static func percent(_ ratio: Double) -> String {
        "\(Int((ratio * 100).rounded()))%"
    }

    static func clock(_ normalizedMinute: Double) -> String {
        let minute = ((Int(normalizedMinute.rounded()) % 1440) + 1440) % 1440
        return String(format: "%02d:%02d", minute / 60, minute % 60)
    }
}

/// Dashboard 中的睡眠分析入口摘要。
struct SleepAnalysisPreviewCard: View {
    let report: SleepPatternReport?

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "moon.stars.fill")
                .font(.title2)
                .foregroundStyle(.indigo)
                .frame(width: 42, height: 42)
                .background(Color.indigo.opacity(0.12), in: Circle())
            if let report {
                VStack(alignment: .leading, spacing: 3) {
                    Text("30 天睡眠模式")
                        .font(.subheadline.weight(.semibold))
                    Text("平均 \(SleepAnalysisView.duration(report.averageAsleepMinutes)) · \(report.regularityLabel)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 1) {
                    Text("\(report.overallScore)")
                        .font(.title3.bold())
                    Text("趋势分")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            } else {
                VStack(alignment: .leading, spacing: 3) {
                    Text("睡眠模式分析")
                        .font(.subheadline.weight(.semibold))
                    Text("同步睡眠后查看时长、规律和分期")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
        }
        .padding(.vertical, 4)
    }
}

private struct SleepMetricCard: View {
    let title: String
    let value: String
    let detail: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Image(systemName: icon)
                .foregroundStyle(color)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            Text(detail)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.background, in: RoundedRectangle(cornerRadius: 16))
    }
}

private struct SleepStageShare: Identifiable {
    let stage: SleepStageKind
    let ratio: Double
    var id: SleepStageKind { stage }
}

private struct SleepNightDetailView: View {
    let night: SleepNight

    var body: some View {
        List {
            Section("概览") {
                LabeledContent("实际睡眠", value: SleepAnalysisView.duration(night.asleepMinutes))
                LabeledContent("卧床时长", value: SleepAnalysisView.duration(night.inBedMinutes))
                LabeledContent("睡眠效率", value: SleepAnalysisView.percent(night.efficiency))
                LabeledContent("入睡", value: night.sleepOnset.formatted(date: .omitted, time: .shortened))
                LabeledContent("起床", value: night.wakeTime.formatted(date: .omitted, time: .shortened))
                LabeledContent("夜间清醒", value: "\(night.awakenings) 次")
                LabeledContent("趋势分", value: "\(night.derivedScore)")
                if let sourceScore = night.sourceScore {
                    LabeledContent("小米睡眠分", value: "\(sourceScore)")
                }
            }

            Section("睡眠分期") {
                ForEach(Array(night.stageRows.enumerated()), id: \.offset) { item in
                    let row = item.element
                    HStack {
                        Circle()
                            .fill(row.stage.color)
                            .frame(width: 9, height: 9)
                        Text(row.stage.displayName)
                        Spacer()
                        Text(SleepAnalysisView.duration(row.minutes))
                            .foregroundStyle(.secondary)
                    }
                }
                if night.unclassifiedMinutes > 1 {
                    LabeledContent(
                        "未分类卧床时间",
                        value: SleepAnalysisView.duration(night.unclassifiedMinutes)
                    )
                }
            }

            Section {
                Text("夜间清醒次数只统计入睡后、最终醒来前持续至少 2 分钟的清醒分段。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle(night.wakeDate.formatted(.dateTime.month().day().weekday(.wide)))
        .navigationBarTitleDisplayMode(.inline)
    }
}

private extension SleepStageKind {
    var displayName: String {
        switch self {
        case .inBed: "卧床"
        case .awake: "清醒"
        case .core: "核心睡眠"
        case .deep: "深度睡眠"
        case .rem: "REM 睡眠"
        case .asleepUnspecified: "未细分睡眠"
        }
    }

    var color: Color {
        switch self {
        case .inBed: .gray
        case .awake: .orange
        case .core, .asleepUnspecified: .cyan
        case .deep: .indigo
        case .rem: .purple
        }
    }
}

private extension SleepInsightTone {
    var icon: String {
        switch self {
        case .positive: "checkmark.circle.fill"
        case .attention: "exclamationmark.circle.fill"
        case .neutral: "info.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .positive: .green
        case .attention: .orange
        case .neutral: .blue
        }
    }
}
