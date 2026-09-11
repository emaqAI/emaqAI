import Foundation

struct ProcessUsage: Identifiable {
    let id: Int32
    let name: String
    let cpuPercent: Double
}

/// Samples per-process CPU usage by shelling out to `top`. A single sample
/// (`-l 1`) reports each process's average %CPU since it launched, which
/// reads as ~0 for long-running daemons — two samples give `top` a real
/// interval to measure against, so only the second (later) block is kept.
final class ProcessMonitor {
    func sampleTopProcesses(limit: Int = 8) -> [ProcessUsage] {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/top")
        task.arguments = ["-l", "2", "-stats", "pid,command,cpu", "-o", "cpu", "-n", "\(limit)"]

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe()

        do {
            try task.run()
        } catch {
            return []
        }
        task.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: data, encoding: .utf8) else { return [] }

        var results: [ProcessUsage] = []
        var pastHeader = false
        for line in output.split(separator: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("PID") {
                pastHeader = true
                results = [] // start of a new sample block; keep only the latest
                continue
            }
            guard pastHeader, !trimmed.isEmpty else { continue }

            let parts = trimmed.split(separator: " ", omittingEmptySubsequences: true)
            guard parts.count >= 3,
                  let pid = Int32(parts[0]),
                  let cpu = Double(parts.last!.replacingOccurrences(of: "%", with: "")) else { continue }

            let name = parts[1..<(parts.count - 1)].joined(separator: " ")
            results.append(ProcessUsage(id: pid, name: name, cpuPercent: cpu))
        }
        return Array(results.prefix(limit))
    }
}
