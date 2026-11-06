import Foundation

/// One sensor snapshot taken by the background logger.
struct StatsSample {
    let cpuUsage: Double
    let cpuTemperature: Double?
    let gpuTemperature: Double?
    let totalPower: Double?
    let cpuPower: Double?
}

/// Running totals for one calendar day. Only aggregates are kept, so a
/// year of data stays around 100 KB.
struct DailyStats: Codable, Identifiable {
    let day: String // yyyy-MM-dd, local time
    var samples = 0
    var cpuUsageSum = 0.0
    var cpuTemperatureSamples = 0
    var cpuTemperatureSum = 0.0
    var cpuTemperatureMax = 0.0
    var gpuTemperatureSamples = 0
    var gpuTemperatureSum = 0.0
    var gpuTemperatureMax = 0.0
    var energyWh = 0.0
    var cpuEnergyWh = 0.0
    var hotMinutes = 0.0

    var id: String { day }
    var date: Date? { StatsStore.dayFormatter.date(from: day) }
    var cpuTemperatureAverage: Double? {
        cpuTemperatureSamples > 0 ? cpuTemperatureSum / Double(cpuTemperatureSamples) : nil
    }

    mutating func add(_ sample: StatsSample, interval: TimeInterval) {
        samples += 1
        cpuUsageSum += sample.cpuUsage
        if let t = sample.cpuTemperature {
            cpuTemperatureSamples += 1
            cpuTemperatureSum += t
            cpuTemperatureMax = max(cpuTemperatureMax, t)
            if t >= StatsStore.hotThreshold { hotMinutes += interval / 60 }
        }
        if let t = sample.gpuTemperature {
            gpuTemperatureSamples += 1
            gpuTemperatureSum += t
            gpuTemperatureMax = max(gpuTemperatureMax, t)
        }
        if let p = sample.totalPower { energyWh += p * interval / 3600 }
        if let p = sample.cpuPower { cpuEnergyWh += p * interval / 3600 }
    }
}

/// Totals over a set of days, e.g. the last 365.
struct StatsSummary {
    let loggedHours: Double
    let energyKWh: Double
    let averagePower: Double?
    let averageCPUTemperature: Double?
    let maxCPUTemperature: Double?
    let hotHours: Double

    init(days: [DailyStats]) {
        let samples = days.reduce(0) { $0 + $1.samples }
        loggedHours = Double(samples) * StatsStore.sampleInterval / 3600
        let energyWh = days.reduce(0) { $0 + $1.energyWh }
        energyKWh = energyWh / 1000
        averagePower = loggedHours > 0 ? energyWh / loggedHours : nil
        let temperatureSamples = days.reduce(0) { $0 + $1.cpuTemperatureSamples }
        averageCPUTemperature = temperatureSamples > 0
            ? days.reduce(0) { $0 + $1.cpuTemperatureSum } / Double(temperatureSamples)
            : nil
        maxCPUTemperature = days.filter { $0.cpuTemperatureSamples > 0 }.map(\.cpuTemperatureMax).max()
        hotHours = days.reduce(0) { $0 + $1.hotMinutes } / 60
    }
}

enum StatsStore {
    /// Must match StartInterval of the logger LaunchAgent.
    static let sampleInterval: TimeInterval = 60
    static let hotThreshold = 85.0
    static let retentionDays = 400

    static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    static var fileURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("CPU Monitor AI", isDirectory: true)
            .appendingPathComponent("daily-stats.json")
    }

    static func load() -> [DailyStats] {
        guard let data = try? Data(contentsOf: fileURL) else { return [] }
        return (try? JSONDecoder().decode([DailyStats].self, from: data)) ?? []
    }

    static func record(_ sample: StatsSample, at date: Date = Date()) throws {
        var days = load()
        let day = dayFormatter.string(from: date)
        if days.last?.day != day {
            days.append(DailyStats(day: day))
        }
        days[days.count - 1].add(sample, interval: sampleInterval)
        if days.count > retentionDays {
            days.removeFirst(days.count - retentionDays)
        }
        try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(),
                                                withIntermediateDirectories: true)
        // Atomic so the app never reads a half-written file.
        try JSONEncoder().encode(days).write(to: fileURL, options: .atomic)
    }

    static func lastYear(of days: [DailyStats], now: Date = Date()) -> [DailyStats] {
        guard let cutoff = Calendar.current.date(byAdding: .day, value: -365, to: now) else { return days }
        return days.filter { ($0.date ?? .distantPast) > cutoff }
    }
}
