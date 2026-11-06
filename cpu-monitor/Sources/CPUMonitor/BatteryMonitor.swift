import Foundation
import IOKit

struct BatteryReading {
    let externalConnected: Bool
    /// Positive while charging, negative while discharging.
    let watts: Double
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
