import SwiftUI
import Charts

struct ContentView: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                header

                GroupBox("Zużycie rdzeni logicznych") {
                    coreChart
                        .frame(height: 130)
                        .padding(.top, 6)
                }

                GroupBox("Historia zużycia (ostatnie próbki)") {
                    historyChart
                        .frame(height: 100)
                        .padding(.top, 6)
                }

                GroupBox("Historia temperatury") {
                    temperatureChart
                        .frame(height: 110)
                        .padding(.top, 6)
                }

                GroupBox("Statystyki roczne (ostatnie 365 dni)") {
                    yearlyStats
                        .padding(.top, 6)
                }

                GroupBox("Najbardziej obciążające procesy") {
                    processTable
                }
            }
            .padding(16)
        }
        .frame(minWidth: 680, minHeight: 560)
        .onAppear { state.start() }
        .onDisappear { state.stop() }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 18) {
                stat(state.isOnBattery ? "Pobór całego Maca (z baterii)" : "Pobór całego Maca (z zasilacza)") {
                    wattsText(state.totalPower)
                }
                .help("Suma wiersza „Moc” w tabeli poniżej")
                ForEach(Array(state.fanRPMs.enumerated()), id: \.offset) { index, rpm in
                    stat("Wentylator \(index + 1)") {
                        Text("\(Int(rpm)) RPM")
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 6) {
                    Text("Rdzenie logiczne: \(state.coreUsages.count)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Picker("Odświeżanie", selection: $state.refreshInterval) {
                        ForEach(AppState.refreshOptions, id: \.self) { seconds in
                            Text("co \(Int(seconds)) s").tag(seconds)
                        }
                    }
                    .pickerStyle(.menu)
                    .fixedSize()
                }
            }
            componentTable
        }
    }

    /// Power-only columns that make the "Moc" row add up to the total.
    private var extraPowerColumns: [(label: String, watts: Double?)] {
        var columns: [(label: String, watts: Double?)] = [("Ekran, RAM, dysk…", state.otherPower)]
        if let charging = state.batteryChargingPower {
            columns.append(("Ładowanie baterii", charging))
        }
        return columns
    }

    private var componentTable: some View {
        Grid(alignment: .leading, horizontalSpacing: 22, verticalSpacing: 2) {
            GridRow {
                Color.clear.gridCellUnsizedAxes([.horizontal, .vertical])
                caption("CPU")
                ForEach(state.gpus) { gpu in
                    caption(gpu.name)
                }
                ForEach(extraPowerColumns.indices, id: \.self) { index in
                    caption(extraPowerColumns[index].label)
                }
            }
            GridRow {
                caption("Obciążenie")
                percentText(state.overallUsage).modifier(TableValue())
                ForEach(state.gpus) { gpu in
                    Group {
                        if gpu.isAsleep {
                            Text("uśpione").foregroundStyle(.secondary)
                        } else {
                            percentText(gpu.utilization)
                        }
                    }
                    .modifier(TableValue())
                }
                emptyCells(extraPowerColumns.count)
            }
            GridRow {
                caption("Temp.")
                temperatureText(state.temperature).modifier(TableValue())
                ForEach(state.gpus) { gpu in
                    temperatureText(gpu.temperature)
                        .modifier(TableValue())
                        .opacity(gpu.isAsleep ? 0.4 : 1)
                }
                emptyCells(extraPowerColumns.count)
            }
            GridRow {
                caption("Moc")
                wattsText(state.cpuPower).modifier(TableValue())
                ForEach(state.gpus) { gpu in
                    wattsText(gpu.power)
                        .modifier(TableValue())
                        .opacity(gpu.isAsleep ? 0.4 : 1)
                }
                ForEach(extraPowerColumns.indices, id: \.self) { index in
                    wattsText(extraPowerColumns[index].watts).modifier(TableValue())
                }
            }
        }
    }

    private func emptyCells(_ count: Int) -> some View {
        ForEach(0..<count, id: \.self) { _ in
            Color.clear.gridCellUnsizedAxes([.horizontal, .vertical])
        }
    }

    @ViewBuilder
    private func percentText(_ value: Double?) -> some View {
        if let value {
            Text("\(value, specifier: "%.0f")%")
        } else {
            noData
        }
    }

    private func caption(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize()
    }

    private struct TableValue: ViewModifier {
        func body(content: Content) -> some View {
            content
                .font(.system(size: 20, weight: .semibold, design: .rounded))
                .lineLimit(1)
                .fixedSize()
        }
    }

    private func stat<Content: View>(_ label: String, @ViewBuilder value: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            value()
                .font(.system(size: 24, weight: .semibold, design: .rounded))
                .lineLimit(1)
        }
        .fixedSize()
    }

    @ViewBuilder
    private func temperatureText(_ value: Double?) -> some View {
        if let value {
            Text("\(value, specifier: "%.1f")°C")
                .foregroundStyle(colorForTemperature(value))
        } else {
            noData
        }
    }

    @ViewBuilder
    private func wattsText(_ value: Double?) -> some View {
        if let value {
            Text("\(value, specifier: "%.1f") W")
        } else {
            noData
        }
    }

    private var noData: some View {
        Text("—").foregroundStyle(.secondary)
    }

    private func colorForTemperature(_ t: Double) -> Color {
        switch t {
        case ..<60: return .green
        case 60..<80: return .orange
        default: return .red
        }
    }

    private var coreChart: some View {
        Chart {
            ForEach(Array(state.coreUsages.enumerated()), id: \.offset) { index, usage in
                BarMark(
                    x: .value("Rdzeń", "CPU \(index)"),
                    y: .value("Użycie %", usage)
                )
                .foregroundStyle(by: .value("Rdzeń", "CPU \(index)"))
            }
        }
        .chartYScale(domain: 0...100)
        .chartLegend(.hidden)
    }

    private var historyChart: some View {
        Chart {
            ForEach(Array(state.coreHistory.enumerated()), id: \.offset) { coreIndex, history in
                ForEach(Array(history.enumerated()), id: \.offset) { sampleIndex, value in
                    LineMark(
                        x: .value("Próbka", sampleIndex),
                        y: .value("Użycie %", value),
                        series: .value("Rdzeń", "CPU \(coreIndex)")
                    )
                }
            }
        }
        .chartYScale(domain: 0...100)
        .chartLegend(.hidden)
    }

    private var temperatureChart: some View {
        Chart {
            RuleMark(y: .value("Próg throttlingu", 85))
                .foregroundStyle(.secondary.opacity(0.5))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))

            temperatureSeries("CPU", state.temperatureHistory)
            temperatureSeries("GPU zintegr.", state.integratedGPUTemperatureHistory)
            temperatureSeries("GPU dedyk.", state.discreteGPUTemperatureHistory)
        }
        .chartForegroundStyleScale([
            "CPU": Color.orange,
            "GPU zintegr.": Color.purple,
            "GPU dedyk.": Color.teal
        ])
        .chartLegend(position: .top, alignment: .trailing)
        .chartYScale(domain: 30...105)
    }

    private func temperatureSeries(_ name: String, _ history: [Double]) -> some ChartContent {
        ForEach(Array(history.enumerated()), id: \.offset) { index, value in
            LineMark(
                x: .value("Próbka", index),
                y: .value("Temperatura", value),
                series: .value("Czujnik", name)
            )
            .foregroundStyle(by: .value("Czujnik", name))
            .interpolationMethod(.catmullRom)
        }
    }

    @ViewBuilder
    private var yearlyStats: some View {
        let days = StatsStore.lastYear(of: state.dailyStats)
        if days.isEmpty {
            Text("Zbieranie danych — pierwszy pomiar pojawi się w ciągu minuty.")
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            let summary = StatsSummary(days: days)
            let range = chartRange(days)
            VStack(alignment: .leading, spacing: 10) {
                Grid(alignment: .leading, horizontalSpacing: 22, verticalSpacing: 6) {
                    GridRow {
                        yearStat("Zarejestrowano", formatDuration(hours: summary.loggedHours))
                        yearStat("Zużyta energia", formatEnergy(kWh: summary.energyKWh))
                        yearStat("Średni pobór", summary.averagePower.map { String(format: "%.1f W", $0) })
                    }
                    GridRow {
                        yearStat("Śr. temp. CPU", summary.averageCPUTemperature.map { String(format: "%.1f°C", $0) })
                        yearStat("Maks. temp. CPU", summary.maxCPUTemperature.map { String(format: "%.1f°C", $0) })
                        yearStat("Czas ≥ \(Int(StatsStore.hotThreshold))°C", formatDuration(hours: summary.hotHours))
                    }
                }
                dailyTemperatureChart(days)
                    .chartXScale(domain: range)
                    .chartXAxis { dayAxis }
                    .frame(height: 90)
                dailyEnergyChart(days)
                    .chartXScale(domain: range)
                    .chartXAxis { dayAxis }
                    .frame(height: 70)
            }
        }
    }

    /// At least the last 30 days, growing to the full year as data piles up,
    /// so a single day of data isn't stretched across the whole axis.
    private func chartRange(_ days: [DailyStats]) -> ClosedRange<Date> {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let monthAgo = calendar.date(byAdding: .day, value: -29, to: today) ?? today
        let first = days.compactMap(\.date).min() ?? today
        let end = calendar.date(byAdding: .day, value: 1, to: today) ?? today
        return min(first, monthAgo)...end
    }

    private var dayAxis: some AxisContent {
        AxisMarks {
            AxisGridLine()
            AxisValueLabel(format: .dateTime.day().month(.abbreviated))
        }
    }

    private func formatDuration(hours: Double) -> String {
        hours < 1 ? "\(Int((hours * 60).rounded())) min" : String(format: "%.1f h", hours)
    }

    private func formatEnergy(kWh: Double) -> String {
        kWh < 1 ? String(format: "%.0f Wh", kWh * 1000) : String(format: "%.2f kWh", kWh)
    }

    private func yearStat(_ label: String, _ value: String?) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value ?? "—")
                .font(.system(size: 16, weight: .semibold, design: .rounded))
        }
        .fixedSize()
    }

    private func dailyTemperatureChart(_ days: [DailyStats]) -> some View {
        Chart {
            RuleMark(y: .value("Próg", StatsStore.hotThreshold))
                .foregroundStyle(.secondary.opacity(0.5))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
            ForEach(days) { day in
                if let date = day.date, let average = day.cpuTemperatureAverage {
                    LineMark(x: .value("Dzień", date, unit: .day),
                             y: .value("°C", average),
                             series: .value("Seria", "Średnia"))
                        .foregroundStyle(by: .value("Seria", "Średnia temp. CPU"))
                        .symbol(.circle)
                    LineMark(x: .value("Dzień", date, unit: .day),
                             y: .value("°C", day.cpuTemperatureMax),
                             series: .value("Seria", "Maks."))
                        .foregroundStyle(by: .value("Seria", "Maks. temp. CPU"))
                        .symbol(.circle)
                }
            }
        }
        .chartForegroundStyleScale(["Średnia temp. CPU": Color.orange, "Maks. temp. CPU": Color.red])
        .chartLegend(position: .top, alignment: .trailing)
        .chartYScale(domain: 30...105)
    }

    private func dailyEnergyChart(_ days: [DailyStats]) -> some View {
        Chart {
            ForEach(days) { day in
                if let date = day.date {
                    BarMark(x: .value("Dzień", date, unit: .day),
                            y: .value("Wh", day.energyWh))
                        .foregroundStyle(.blue.opacity(0.7))
                }
            }
        }
        .chartYAxisLabel("Energia (Wh)")
    }

    private var processTable: some View {
        VStack(spacing: 0) {
            ForEach(state.topProcesses) { process in
                HStack {
                    Text(process.name)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer()
                    Text("PID \(process.id)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(process.cpuPercent, specifier: "%.1f")%")
                        .font(.system(.body, design: .monospaced))
                        .frame(width: 70, alignment: .trailing)
                }
                .padding(.vertical, 3)
                Divider()
            }
            if state.topProcesses.isEmpty {
                Text("Zbieranie danych…")
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 8)
            }
        }
    }
}
