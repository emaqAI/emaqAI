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

    /// Reads a floating point temperature value (°C) for the given 4-char SMC key.
    func readTemperature(_ key: String) -> Double? {
        guard let keyInfo = readKeyInfo(key), keyInfo.dataSize > 0 else { return nil }

        var input = SMCParamStruct()
        input.key = fourCharCode(key)
        input.keyInfo = keyInfo
        input.data8 = Selector.kSMCReadKey.rawValue

        guard let output = callSMC(&input), output.result == 0 else { return nil }

        let bytes = [output.bytes.0, output.bytes.1, output.bytes.2, output.bytes.3]

        // Most temperature keys use "sp78" (signed fixed point) fixed-point encoding.
        let msb = Int16(bytes[0])
        let lsb = Int16(bytes[1])
        let raw = (msb << 6) + (lsb >> 2)
        let value = Double(raw) / 64.0
        if value > 0 && value < 150 { return value }
        return nil
    }

    /// Best-effort CPU package/die temperature across Intel and Apple Silicon Macs.
    func cpuTemperature() -> Double? {
        let candidateKeys = [
            "TC0P", // Intel CPU proximity
            "TC0D", // Intel CPU die
            "TC0E", "TC0F",
            "Tp09", "Tp0T", // Apple Silicon P-cores
            "Te05", "Te0L", // Apple Silicon E-cores
            "Tp01", "Tp05"
        ]
        for key in candidateKeys {
            if let t = readTemperature(key) { return t }
        }
        return nil
    }
}
