import Foundation
import Combine

@MainActor
final class AppState: ObservableObject {
    @Published var coreUsages: [Double] = []
    @Published var overallUsage: Double = 0
    @Published var temperature: Double?
    @Published var topProcesses: [ProcessUsage] = []
    @Published var coreHistory: [[Double]] = [] // rolling history per core, for sparkline-style chart

    private let coreMonitor = CoreUsageMonitor()
    private let processMonitor = ProcessMonitor()
    private var timer: Timer?
    private let historyLength = 30

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
        if ProcessInfo.processInfo.environment["CPUMONITOR_DEBUG"] != nil {
            print("DEBUG temp=\(String(describing: temperature)) overall=\(overallUsage)")
            fflush(stdout)
        }
        topProcesses = processMonitor.sampleTopProcesses()

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
