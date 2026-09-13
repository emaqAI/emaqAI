import Foundation
import IOKit

struct SMCVersion { var major: UInt8=0, minor: UInt8=0, build: UInt8=0, reserved: UInt8=0; var release: UInt16=0 }
struct SMCPLimitData { var version: UInt16=0, length: UInt16=0; var cpuPLimit: UInt32=0, gpuPLimit: UInt32=0, memPLimit: UInt32=0 }
struct SMCKeyInfoData { var dataSize: UInt32=0, dataType: UInt32=0; var dataAttributes: UInt8=0 }
struct SMCParamStruct {
    var key: UInt32 = 0
    var vers = SMCVersion()
    var pLimitData = SMCPLimitData()
    var keyInfo = SMCKeyInfoData()
    var padding: UInt16 = 0
    var result: UInt8 = 0
    var status: UInt8 = 0
    var data8: UInt8 = 0
    var data32: UInt32 = 0
    var bytes: (UInt8,UInt8,UInt8,UInt8,UInt8,UInt8,UInt8,UInt8,UInt8,UInt8,UInt8,UInt8,UInt8,UInt8,UInt8,UInt8,UInt8,UInt8,UInt8,UInt8,UInt8,UInt8,UInt8,UInt8,UInt8,UInt8,UInt8,UInt8,UInt8,UInt8,UInt8,UInt8) = (0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0)
}

var conn: io_connect_t = 0
let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSMC"))
guard service != 0, IOServiceOpen(service, mach_task_self_, 0, &conn) == kIOReturnSuccess else {
    print("no SMC connection"); exit(1)
}
IOObjectRelease(service)

func fourCC(_ s: String) -> UInt32 {
    var r: UInt32 = 0
    for b in s.utf8 { r = (r << 8) + UInt32(b) }
    return r
}
func readKeyInfo(_ key: String) -> SMCKeyInfoData? {
    var input = SMCParamStruct(); input.key = fourCC(key); input.data8 = 9
    var output = SMCParamStruct()
    let result = withUnsafePointer(to: &input) { inPtr -> kern_return_t in
        withUnsafeMutablePointer(to: &output) { outPtr -> kern_return_t in
            var outSize = MemoryLayout<SMCParamStruct>.stride
            return IOConnectCallStructMethod(conn, 2, inPtr, MemoryLayout<SMCParamStruct>.stride, outPtr, &outSize)
        }
    }
    guard result == kIOReturnSuccess, output.result == 0 else { return nil }
    return output.keyInfo
}
func readTemp(_ key: String) -> Double? {
    guard let info = readKeyInfo(key), info.dataSize > 0 else { return nil }
    var input = SMCParamStruct(); input.key = fourCC(key); input.keyInfo = info; input.data8 = 5
    var output = SMCParamStruct()
    let result = withUnsafePointer(to: &input) { inPtr -> kern_return_t in
        withUnsafeMutablePointer(to: &output) { outPtr -> kern_return_t in
            var outSize = MemoryLayout<SMCParamStruct>.stride
            return IOConnectCallStructMethod(conn, 2, inPtr, MemoryLayout<SMCParamStruct>.stride, outPtr, &outSize)
        }
    }
    guard result == kIOReturnSuccess, output.result == 0 else { return nil }
    let msb = Int16(output.bytes.0), lsb = Int16(output.bytes.1)
    let raw = (msb << 6) + (lsb >> 2)
    return Double(raw) / 64.0
}

let coreKeys = ["TC0D","TC0E","TC0F","TC0G","TC0H","TCXC","TCGC"]
let readings = coreKeys.compactMap { readTemp($0) }
if let hottest = readings.max() {
    print(String(format: "CPU (najgorętszy rdzeń): %.1f°C", hottest))
} else {
    print("brak odczytu temperatury")
}
IOServiceClose(conn)
