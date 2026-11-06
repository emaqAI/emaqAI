import Foundation
import IOKit

// Minimal Apple SMC client for reading temperature sensor keys.
// Based on the long-standing public SMC access pattern used by tools
// like smcFanControl / iStat (IOConnectCallStructMethod against "AppleSMC").

private let KERNEL_INDEX_SMC: UInt32 = 2

private enum Selector: UInt8 {
    case kSMCHandleYPCEvent = 2
    case kSMCReadKey = 5
    case kSMCWriteKey = 6
    case kSMCGetKeyCount = 7
    case kSMCReadIndex = 8
}

private struct SMCVersion {
    var major: UInt8 = 0
    var minor: UInt8 = 0
    var build: UInt8 = 0
    var reserved: UInt8 = 0
    var release: UInt16 = 0
}

private struct SMCPLimitData {
    var version: UInt16 = 0
    var length: UInt16 = 0
    var cpuPLimit: UInt32 = 0
    var gpuPLimit: UInt32 = 0
    var memPLimit: UInt32 = 0
}

private struct SMCKeyInfoData {
    var dataSize: UInt32 = 0
    var dataType: UInt32 = 0
    var dataAttributes: UInt8 = 0
}

private struct SMCParamStruct {
    var key: UInt32 = 0
    var vers = SMCVersion()
    var pLimitData = SMCPLimitData()
    var keyInfo = SMCKeyInfoData()
    var padding: UInt16 = 0
    var result: UInt8 = 0
    var status: UInt8 = 0
    var data8: UInt8 = 0
    var data32: UInt32 = 0
    var bytes: (UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8) =
        (0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0)
}

final class SMC {
    static let shared = SMC()

    private var connection: io_connect_t = 0
    private var isOpen = false

    private init() {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSMC"))
        guard service != 0 else { return }
        let result = IOServiceOpen(service, mach_task_self_, 0, &connection)
        IOObjectRelease(service)
        isOpen = (result == kIOReturnSuccess)
    }

    deinit {
        if isOpen { IOServiceClose(connection) }
    }

    private func fourCharCode(_ key: String) -> UInt32 {
        var result: UInt32 = 0
        for byte in key.utf8 {
            result = (result << 8) + UInt32(byte)
        }
        return result
    }

    private func callSMC(_ input: inout SMCParamStruct) -> SMCParamStruct? {
        guard isOpen else { return nil }
        var output = SMCParamStruct()
        let inputSize = MemoryLayout<SMCParamStruct>.stride
        var outputSize = MemoryLayout<SMCParamStruct>.stride

        let result = withUnsafePointer(to: &input) { inPtr -> kern_return_t in
            withUnsafeMutablePointer(to: &output) { outPtr -> kern_return_t in
                IOConnectCallStructMethod(connection,
                                          UInt32(Selector.kSMCHandleYPCEvent.rawValue),
                                          inPtr, inputSize,
                                          outPtr, &outputSize)
            }
        }
        guard result == kIOReturnSuccess else { return nil }
        return output
    }

    private func readKeyInfo(_ key: String) -> SMCKeyInfoData? {
        var input = SMCParamStruct()
        input.key = fourCharCode(key)
        input.data8 = Selector.kSMCGetKeyCount.rawValue == 0 ? 0 : 9 // kSMCGetKeyInfo = 9
        guard let output = callSMC(&input), output.result == 0 else { return nil }
        return output.keyInfo
    }

    /// Raw value of a key together with its SMC data type (e.g. "sp78", "flt ").
    private func readKey(_ key: String) -> (dataType: UInt32, output: SMCParamStruct)? {
        guard let keyInfo = readKeyInfo(key), keyInfo.dataSize > 0 else { return nil }

        var input = SMCParamStruct()
        input.key = fourCharCode(key)
        input.keyInfo = keyInfo
        input.data8 = Selector.kSMCReadKey.rawValue

        guard let output = callSMC(&input), output.result == 0 else { return nil }
        return (keyInfo.dataType, output)
    }

    /// Reads a floating point temperature value (°C) for the given 4-char SMC key.
    func readTemperature(_ key: String) -> Double? {
        guard let (_, output) = readKey(key) else { return nil }

        let bytes = [output.bytes.0, output.bytes.1, output.bytes.2, output.bytes.3]

        // Most temperature keys use "sp78" (signed fixed point) fixed-point encoding.
        let msb = Int16(bytes[0])
        let lsb = Int16(bytes[1])
        let raw = (msb << 6) + (lsb >> 2)
        let value = Double(raw) / 64.0
        if value > 0 && value < 150 { return value }
        return nil
    }

    /// CPU core/die temperature, i.e. the sensor macOS actually throttles
    /// against. Reports the hottest core sensor found rather than the first
    /// match: "proximity" keys like TC0P sit near the CPU, not on the die,
    /// and can read 20-30°C cooler than the cores under load — using them
    /// would hide real thermal throttling.
    func cpuTemperature() -> Double? {
        let coreKeys = [
            "TC0D", "TC0E", "TC0F", "TC0G", "TC0H", // Intel per-core die sensors
            "TCXC",
            "Tp09", "Tp0T", // Apple Silicon P-cores
            "Te05", "Te0L", // Apple Silicon E-cores
            "Tp01", "Tp05"
        ]
        let readings = coreKeys.compactMap { readTemperature($0) }
        if let hottest = readings.max() { return hottest }

        // Fall back to the proximity sensor if no die sensor responded.
        return readTemperature("TC0P")
    }

    /// Hottest GPU die sensor. On dual-GPU Intel MacBook Pros the discrete GPU
    /// (TG0D) reads a flat 35°C while powered down, so the integrated GPU on
    /// the CPU package (TCGC) is usually the one that matters. TG1D is skipped:
    /// on this hardware it returns a constant out-of-range value.
    func gpuTemperature() -> Double? {
        let gpuKeys = [
            "TG0D", "TCGC",                 // Intel Macs: discrete GPU die, integrated GPU
            "Tg05", "Tg0D", "Tg0L", "Tg0T"  // Apple Silicon GPU clusters
        ]
        let readings = gpuKeys.compactMap { readTemperature($0) }
        if let hottest = readings.max() { return hottest }
        return readTemperature("TG0P")
    }

    /// Reads a fan RPM value ("fpe2" fixed point: value = raw / 4).
    func readFanRPM(_ key: String) -> Double? {
        guard let (_, output) = readKey(key) else { return nil }
        let raw = (UInt16(output.bytes.0) << 8) | UInt16(output.bytes.1)
        return Double(raw) / 4.0
    }

    /// Actual RPM of the fastest fan (F0Ac, F1Ac, ...). Returns nil on fanless Macs.
    func fanRPM() -> Double? {
        let readings = ["F0Ac", "F1Ac", "F2Ac"].compactMap { readFanRPM($0) }
        return readings.max()
    }

    /// Reads a power value in watts. Power keys come as either big-endian
    /// "sp87" fixed point or little-endian "flt " depending on the key.
    func readPower(_ key: String) -> Double? {
        guard let (dataType, output) = readKey(key) else { return nil }
        let b = output.bytes
        switch dataType {
        case fourCharCode("sp87"):
            return Double(Int16(bitPattern: UInt16(b.0) << 8 | UInt16(b.1))) / 128
        case fourCharCode("flt "):
            let bits = UInt32(b.0) | UInt32(b.1) << 8 | UInt32(b.2) << 16 | UInt32(b.3) << 24
            return Double(Float(bitPattern: bits))
        default:
            return nil
        }
    }

    /// Whole CPU package: cores, integrated GPU and uncore.
    func cpuPackagePower() -> Double? { readPower("PCPT") }

    /// Whole machine. On AC this tracks the adapter input (PDTR) one sample later.
    func systemPower() -> Double? { readPower("PSTR") }
}
