import Foundation
import IOKit

struct BatteryReading {
    let externalConnected: Bool
    /// Positive while charging, negative while discharging.
    let watts: Double
}

/// Whole-Mac power draw: adapter input on AC, battery discharge on battery.
struct PowerSnapshot {
    let total: Double?
    let isOnBattery: Bool
    /// Set only while the battery is charging on AC.
    let charging: Double?

    static func read(smc: SMC, battery: BatteryReading? = BatteryMonitor().read()) -> PowerSnapshot {
        let onBattery = battery.map { !$0.externalConnected } ?? false
        if onBattery, let battery {
            return PowerSnapshot(total: max(0, -battery.watts), isOnBattery: true, charging: nil)
        }
        let charging = battery.flatMap { $0.watts > 0.5 ? $0.watts : nil }
        return PowerSnapshot(total: smc.adapterPower(), isOnBattery: false, charging: charging)
    }
}

/// Reads the internal battery's live voltage and current. Returns nil on
/// Macs without a battery.
struct BatteryMonitor {
    func read() -> BatteryReading? {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSmartBattery"))
        guard service != 0 else { return nil }
        defer { IOObjectRelease(service) }

        func number(_ key: String) -> NSNumber? {
            IORegistryEntryCreateCFProperty(service, key as CFString, kCFAllocatorDefault, 0)?
                .takeRetainedValue() as? NSNumber
        }
        guard let millivolts = number("Voltage"), let milliamps = number("Amperage") else { return nil }
        // Amperage is stored as a 64-bit two's complement value when negative.
        let watts = millivolts.doubleValue * Double(milliamps.int64Value) / 1_000_000
        return BatteryReading(externalConnected: number("ExternalConnected")?.boolValue ?? true, watts: watts)
    }
}
