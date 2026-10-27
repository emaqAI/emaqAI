import Foundation

/// Samples per-logical-core CPU usage via host_processor_info.
final class CoreUsageMonitor {
    private var prevInfo: [(user: UInt32, system: UInt32, idle: UInt32, nice: UInt32)] = []

    /// Returns per-core usage percentages (0-100) in logical-core order.
    func sample() -> [Double] {
        var cpuInfo: processor_info_array_t!
        var numCpuInfo: mach_msg_type_number_t = 0
        var numCpus: natural_t = 0

        let result = host_processor_info(mach_host_self(),
                                          PROCESSOR_CPU_LOAD_INFO,
                                          &numCpus,
                                          &cpuInfo,
                                          &numCpuInfo)
        guard result == KERN_SUCCESS, let info = cpuInfo else { return [] }
        defer {
            vm_deallocate(mach_task_self_,
                          vm_address_t(bitPattern: info),
                          vm_size_t(Int(numCpuInfo) * MemoryLayout<Int32>.stride))
        }

        var currentInfo: [(user: UInt32, system: UInt32, idle: UInt32, nice: UInt32)] = []
        let cpuCount = Int(numCpus)
        for i in 0..<cpuCount {
            let base = i * Int(CPU_STATE_MAX)
            let user = UInt32(info[base + Int(CPU_STATE_USER)])
            let system = UInt32(info[base + Int(CPU_STATE_SYSTEM)])
            let idle = UInt32(info[base + Int(CPU_STATE_IDLE)])
            let nice = UInt32(info[base + Int(CPU_STATE_NICE)])
            currentInfo.append((user, system, idle, nice))
        }

        defer { prevInfo = currentInfo }

        guard prevInfo.count == currentInfo.count else {
            return Array(repeating: 0, count: cpuCount)
        }

        var usages: [Double] = []
        for i in 0..<cpuCount {
            let prev = prevInfo[i]
            let curr = currentInfo[i]

            let userDelta = Double(curr.user &- prev.user)
            let systemDelta = Double(curr.system &- prev.system)
            let niceDelta = Double(curr.nice &- prev.nice)
            let idleDelta = Double(curr.idle &- prev.idle)

            let totalDelta = userDelta + systemDelta + niceDelta + idleDelta
            let busy = userDelta + systemDelta + niceDelta
            let usage = totalDelta > 0 ? (busy / totalDelta) * 100.0 : 0
            usages.append(min(max(usage, 0), 100))
        }
        return usages
    }
}
