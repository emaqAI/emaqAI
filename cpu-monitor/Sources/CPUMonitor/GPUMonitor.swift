import Foundation
import IOKit

struct GPUInfo: Identifiable {
    enum Kind: Int { case integrated, discrete, other }

    let id: UInt64
    let name: String
    let kind: Kind
    let utilization: Double?
    var temperature: Double?
    var power: Double?

    // Below this draw the internal discrete GPU is powered down and its
    // sensor just reports a flat 35°C.
    var isAsleep: Bool { kind == .discrete && (power ?? 0) < 0.5 }
}

/// Lists every GPU macOS has a graphics accelerator for (built-in, eGPU,
/// paravirtual GPU when running inside a VM), with utilization from IOKit.
final class GPUMonitor {
    func sample() -> [GPUInfo] {
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching("IOAccelerator"), &iterator) == kIOReturnSuccess else {
            return []
        }
        defer { IOObjectRelease(iterator) }

        var gpus: [GPUInfo] = []
        var service = IOIteratorNext(iterator)
        while service != 0 {
            defer {
                IOObjectRelease(service)
                service = IOIteratorNext(iterator)
            }
            var entryID: UInt64 = 0
            IORegistryEntryGetRegistryEntryID(service, &entryID)
            let ioClass = property(service, "IOClass") as? String ?? ""
            let stats = property(service, "PerformanceStatistics") as? [String: Any]
            let utilization = (stats?["Device Utilization %"] as? NSNumber)?.doubleValue
            gpus.append(GPUInfo(
                id: entryID,
                name: modelName(service) ?? ioClass,
                kind: kind(ioClass: ioClass, tunnelled: isTunnelled(service)),
                utilization: utilization
            ))
        }
        return gpus.sorted { ($0.kind.rawValue, $0.name) < ($1.kind.rawValue, $1.name) }
    }

    private func property(_ service: io_service_t, _ key: String) -> Any? {
        IORegistryEntryCreateCFProperty(service, key as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue()
    }

    private func parentProperty(_ service: io_service_t, _ key: String) -> Any? {
        IORegistryEntrySearchCFProperty(service, kIOServicePlane, key as CFString, kCFAllocatorDefault,
                                        IOOptionBits(kIORegistryIterateParents | kIORegistryIterateRecursively))
    }

    /// Marketing name from the GPU's PCI device, e.g. "AMD Radeon R9 M370X".
    private func modelName(_ service: io_service_t) -> String? {
        switch parentProperty(service, "model") {
        case let data as Data: return String(decoding: data.prefix { $0 != 0 }, as: UTF8.self)
        case let string as String: return string
        default: return nil
        }
    }

    /// Thunderbolt-attached (eGPU) devices are tunnelled PCIe.
    private func isTunnelled(_ service: io_service_t) -> Bool {
        (parentProperty(service, "IOPCITunnelled") as? Bool) == true
    }

    private func kind(ioClass: String, tunnelled: Bool) -> GPUInfo.Kind {
        if tunnelled { return .other }
        if ioClass.hasPrefix("Intel") || ioClass.hasPrefix("AGX") { return .integrated }
        if ioClass.hasPrefix("AMD") || ioClass.hasPrefix("NVDA") || ioClass.hasPrefix("GeForce") { return .discrete }
        return .other
    }
}
