import Foundation
import Combine

@MainActor
final class AppState: ObservableObject {
    @Published var coreUsages: [Double] = []
    @Published var overallUsage: Double = 0
    @Published var temperature: Double?
    @Published var topProcesses: [ProcessUsage] = []
    @Published var coreHistory: [[Double]] = [] // rolling history per core, for sparkline-style chart
    @Published var temperatureHistory: [Double] = []

    private let coreMonitor = CoreUsageMonitor()
    private let processMonitor = ProcessMonitor()
    private var timer: Timer?
    private let historyLength = 30
    private var tickCount = 0
    private var isSamplingProcesses = false

    func start() {
        // Prime the delta-based core sampler so the first displayed sample isn't empty.
        _ = coreMonitor.sample()

        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                self.tick()
            }
        }
        RunLoop.main.add(timer!, forMode: .common)
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func tick() {
        let usages = coreMonitor.sample()
        coreUsages = usages
        overallUsage = usages.isEmpty ? 0 : usages.reduce(0, +) / Double(usages.count)
        temperature = SMC.shared.cpuTemperature()
        if let temperature {
            temperatureHistory.append(temperature)
            if temperatureHistory.count > historyLength {
                temperatureHistory.removeFirst()
            }
        }

        // `top -l 2` takes ~1s and would block the main actor if awaited here,
        // so it's kicked off on a background task at a slower cadence than the
        // 1s core/temperature tick instead of running (and blocking) every tick.
        tickCount += 1
        if !isSamplingProcesses && tickCount % 5 == 0 {
            isSamplingProcesses = true
            let monitor = processMonitor
            Task.detached(priority: .utility) { [weak self] in
                let result = monitor.sampleTopProcesses()
                await MainActor.run {
                    self?.topProcesses = result
                    self?.isSamplingProcesses = false
                }
            }
        }

        if coreHistory.count != usages.count {
            coreHistory = usages.map { [$0] }
        } else {
            for i in 0..<usages.count {
                coreHistory[i].append(usages[i])
                if coreHistory[i].count > historyLength {
                    coreHistory[i].removeFirst()
                }
            }
        }
    }
}
