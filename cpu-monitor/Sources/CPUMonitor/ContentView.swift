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
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 18) {
                    stat("Zużycie CPU") {
                        Text("\(state.overallUsage, specifier: "%.1f")%")
                    }
                    stat("Temp. CPU") {
                        temperatureText(state.temperature)
                    }
                    stat("Temp. GPU") {
                        temperatureText(state.gpuTemperature)
                    }
                    stat("Wentylator") {
                        if let fanRPM = state.fanRPM {
                            Text("\(Int(fanRPM)) RPM")
                        } else {
                            noData
                        }
                    }
                }
                HStack(alignment: .top, spacing: 18) {
                    stat("Moc CPU") {
                        wattsText(state.cpuPower)
                    }
                    stat("Moc całkowita") {
                        wattsText(state.systemPower)
                    }
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
        Text("brak danych")
            .font(.system(size: 18, weight: .medium, design: .rounded))
            .foregroundStyle(.secondary)
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
                    y: .value("Temperatura", value),
                    series: .value("Czujnik", "CPU")
                )
                .foregroundStyle(by: .value("Czujnik", "CPU"))
                .interpolationMethod(.catmullRom)
            }

            ForEach(Array(state.gpuTemperatureHistory.enumerated()), id: \.offset) { index, value in
                LineMark(
                    x: .value("Próbka", index),
                    y: .value("Temperatura", value),
                    series: .value("Czujnik", "GPU")
                )
                .foregroundStyle(by: .value("Czujnik", "GPU"))
                .interpolationMethod(.catmullRom)
            }
        }
        .chartForegroundStyleScale(["CPU": Color.orange, "GPU": Color.purple])
        .chartLegend(position: .top, alignment: .trailing)
        .chartYScale(domain: 30...105)
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
