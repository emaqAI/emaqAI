import Foundation

/// `CPUMonitor --log-sample`: takes one snapshot, folds it into today's
/// totals and exits. Run every minute by a LaunchAgent so statistics keep
/// accumulating while the window is closed.
enum StatsLogger {
    static func run() {
        let cores = CoreUsageMonitor()
        _ = cores.sample()
        Thread.sleep(forTimeInterval: 1)
        let usages = cores.sample()

        let smc = SMC.shared
        let sample = StatsSample(
            cpuUsage: usages.isEmpty ? 0 : usages.reduce(0, +) / Double(usages.count),
            cpuTemperature: smc.cpuTemperature(),
            gpuTemperature: smc.integratedGPUTemperature(),
            totalPower: PowerSnapshot.read(smc: smc).total,
            cpuPower: smc.cpuPower()
        )
        do {
            try StatsStore.record(sample)
        } catch {
            FileHandle.standardError.write(Data("CPUMonitor stats logger: \(error)\n".utf8))
            exit(1)
        }
    }
}
