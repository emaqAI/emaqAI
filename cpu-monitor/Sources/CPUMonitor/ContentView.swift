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
        HStack(alignment: .top, spacing: 18) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 18) {
                    ForEach(Array(state.fanRPMs.enumerated()), id: \.offset) { index, rpm in
                        stat("Wentylator \(index + 1)") {
                            Text("\(Int(rpm)) RPM")
                        }
                    }
                    stat("Moc całkowita") {
                        wattsText(state.systemPower)
                    }
                }
                componentTable
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
    }

    private var componentTable: some View {
        Grid(alignment: .leading, horizontalSpacing: 22, verticalSpacing: 2) {
            GridRow {
                Color.clear.gridCellUnsizedAxes([.horizontal, .vertical])
                caption("CPU")
                ForEach(state.gpus) { gpu in
                    caption(gpu.isAsleep ? "\(gpu.name) · uśpione" : gpu.name)
                }
            }
            GridRow {
                caption("Obciążenie")
                percentText(state.overallUsage).modifier(TableValue())
                ForEach(state.gpus) { gpu in
                    percentText(gpu.utilization)
                        .modifier(TableValue())
                        .opacity(gpu.isAsleep ? 0.4 : 1)
                }
            }
            GridRow {
                caption("Temp.")
                temperatureText(state.temperature).modifier(TableValue())
                ForEach(state.gpus) { gpu in
                    temperatureText(gpu.temperature)
                        .modifier(TableValue())
                        .opacity(gpu.isAsleep ? 0.4 : 1)
                }
            }
            GridRow {
                caption("Moc")
                wattsText(state.cpuPower).modifier(TableValue())
                ForEach(state.gpus) { gpu in
                    wattsText(gpu.power)
                        .modifier(TableValue())
                        .opacity(gpu.isAsleep ? 0.4 : 1)
                }
            }
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
