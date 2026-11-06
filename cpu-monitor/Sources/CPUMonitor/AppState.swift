import Foundation
import Combine

@MainActor
final class AppState: ObservableObject {
    static let refreshOptions: [Double] = [1, 2, 5, 10, 30]
    private static let refreshIntervalKey = "refreshInterval"

    @Published var coreUsages: [Double] = []
    @Published var overallUsage: Double = 0
    @Published var temperature: Double?
    @Published var gpus: [GPUInfo] = []
    @Published var fanRPMs: [Double] = []
    @Published var cpuPower: Double?
    @Published var systemPower: Double?
    @Published var topProcesses: [ProcessUsage] = []
    @Published var coreHistory: [[Double]] = [] // rolling history per core, for sparkline-style chart
    @Published var temperatureHistory: [Double] = []
    @Published var integratedGPUTemperatureHistory: [Double] = []
    @Published var discreteGPUTemperatureHistory: [Double] = []
    @Published var refreshInterval: Double {
        didSet {
            UserDefaults.standard.set(refreshInterval, forKey: Self.refreshIntervalKey)
            if timer != nil { scheduleTimer() }
        }
    }

    private let coreMonitor = CoreUsageMonitor()
    private let processMonitor = ProcessMonitor()
    private let gpuMonitor = GPUMonitor()
    private var timer: Timer?
    private let historyLength = 30
    private var isSamplingProcesses = false
    private var lastProcessSample = Date.distantPast
    // `top -l 2` itself costs noticeable CPU, so even at a 1s refresh the
    // process list is never resampled more often than this.
    private let minProcessSampleInterval: TimeInterval = 5

    init() {
        let stored = UserDefaults.standard.double(forKey: Self.refreshIntervalKey)
        refreshInterval = stored > 0 ? stored : 10
    }

    func start() {
        // Prime the delta-based core sampler, then take the first real sample
        // after a second so long intervals don't leave the window empty.
        _ = coreMonitor.sample()
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1))
            self.tick()
        }
        scheduleTimer()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func scheduleTimer() {
        timer?.invalidate()
        let newTimer = Timer(timeInterval: refreshInterval, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                self.tick()
            }
        }
        RunLoop.main.add(newTimer, forMode: .common)
        timer = newTimer
    }

    private func appendCapped(_ value: Double, to history: inout [Double]) {
        history.append(value)
        if history.count > historyLength {
            history.removeFirst()
        }
    }

    /// SMC has one set of sensors for the built-in integrated GPU and one for
    /// the built-in discrete GPU, so only the first GPU of each kind gets
    /// them; any other GPU (eGPU, virtual) shows utilization only.
    private func sampleGPUs(_ smc: SMC) -> [GPUInfo] {
        var assignedKinds = Set<GPUInfo.Kind>()
        return gpuMonitor.sample().map { gpu in
            var gpu = gpu
            guard gpu.kind != .other, assignedKinds.insert(gpu.kind).inserted else { return gpu }
            switch gpu.kind {
            case .integrated:
                gpu.temperature = smc.integratedGPUTemperature()
                gpu.power = smc.integratedGPUPower()
            case .discrete:
                gpu.temperature = smc.discreteGPUTemperature()
                gpu.power = smc.discreteGPUPower()
            case .other:
                break
            }
            return gpu
        }
    }

    private func tick() {
        let usages = coreMonitor.sample()
        coreUsages = usages
        overallUsage = usages.isEmpty ? 0 : usages.reduce(0, +) / Double(usages.count)
        let smc = SMC.shared
        temperature = smc.cpuTemperature()
        fanRPMs = smc.fanRPMs()
        cpuPower = smc.cpuCorePower()
        systemPower = smc.systemPower()
        gpus = sampleGPUs(smc)
        if let temperature { appendCapped(temperature, to: &temperatureHistory) }
        if let t = gpus.first(where: { $0.kind == .integrated })?.temperature {
            appendCapped(t, to: &integratedGPUTemperatureHistory)
        }
        if let t = gpus.first(where: { $0.kind == .discrete })?.temperature {
            appendCapped(t, to: &discreteGPUTemperatureHistory)
        }

        // `top -l 2` takes ~1s and would block the main actor if awaited here,
        // so it's kicked off on a background task instead of run inline.
        if !isSamplingProcesses && Date().timeIntervalSince(lastProcessSample) >= minProcessSampleInterval {
            isSamplingProcesses = true
            lastProcessSample = Date()
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
                appendCapped(usages[i], to: &coreHistory[i])
            }
        }
    }
}
