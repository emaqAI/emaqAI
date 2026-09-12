import SwiftUI
import Charts

struct ContentView: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header

                GroupBox("Zużycie rdzeni logicznych") {
                    coreChart
                        .frame(height: 220)
                        .padding(.top, 8)
                }

                GroupBox("Historia zużycia (ostatnie próbki)") {
                    historyChart
                        .frame(height: 180)
                        .padding(.top, 8)
                }

                GroupBox("Historia temperatury") {
                    temperatureChart
                        .frame(height: 180)
                        .padding(.top, 8)
                }

                GroupBox("Najbardziej obciążające procesy") {
                    processTable
                }
            }
            .padding(20)
        }
        .frame(minWidth: 560, minHeight: 700)
        .onAppear { state.start() }
        .onDisappear { state.stop() }
    }

    private var header: some View {
        HStack(spacing: 24) {
            VStack(alignment: .leading) {
                Text("Zużycie CPU")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("\(state.overallUsage, specifier: "%.1f")%")
                    .font(.system(size: 32, weight: .semibold, design: .rounded))
            }
            VStack(alignment: .leading) {
                Text("Temperatura")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let temp = state.temperature {
                    Text("\(temp, specifier: "%.1f")°C")
                        .font(.system(size: 32, weight: .semibold, design: .rounded))
                        .foregroundStyle(colorForTemperature(temp))
                } else {
                    Text("brak danych")
                        .font(.system(size: 20, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }
            VStack(alignment: .leading) {
                Text("Wentylator")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let fanRPM = state.fanRPM {
                    Text("\(Int(fanRPM)) RPM")
                        .font(.system(size: 32, weight: .semibold, design: .rounded))
                } else {
                    Text("brak danych")
                        .font(.system(size: 20, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            VStack(alignment: .trailing) {
                Text("Rdzenie logiczne")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("\(state.coreUsages.count)")
                    .font(.system(size: 20, weight: .medium, design: .rounded))
            }
        }
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

            ForEach(Array(state.temperatureHistory.enumerated()), id: \.offset) { index, value in
                LineMark(
                    x: .value("Próbka", index),
                    y: .value("Temperatura", value)
                )
                .foregroundStyle(colorForTemperature(value))
                .interpolationMethod(.catmullRom)
            }
        }
        .chartYScale(domain: 40...105)
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
                .padding(.vertical, 4)
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
