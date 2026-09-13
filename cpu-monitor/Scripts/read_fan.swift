import Foundation
import IOKit

private enum Sel: UInt8 { case readKey = 5 }

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
    var input = SMCParamStruct()
    input.key = fourCC(key)
    input.data8 = 9 // kSMCGetKeyInfo
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

func readRaw(_ key: String) -> (bytes: [UInt8], type: UInt32)? {
    guard let info = readKeyInfo(key), info.dataSize > 0 else { return nil }
    var input = SMCParamStruct()
    input.key = fourCC(key)
    input.keyInfo = info
    input.data8 = Sel.readKey.rawValue
    var output = SMCParamStruct()
    let result = withUnsafePointer(to: &input) { inPtr -> kern_return_t in
        withUnsafeMutablePointer(to: &output) { outPtr -> kern_return_t in
            var outSize = MemoryLayout<SMCParamStruct>.stride
            return IOConnectCallStructMethod(conn, 2, inPtr, MemoryLayout<SMCParamStruct>.stride, outPtr, &outSize)
        }
    }
    guard result == kIOReturnSuccess, output.result == 0 else { return nil }
    let b = output.bytes
    return ([b.0,b.1,b.2,b.3,b.4,b.5], info.dataType)
}

// Fan count
if let (bytes, _) = readRaw("FNum") {
    let count = Int(bytes[0])
    print("fan count (FNum) = \(count)")
}

let candidates = ["F0Ac", "F0Mn", "F0Mx", "F0Tg", "FS! ", "F1Ac"]
for key in candidates {
    if let (bytes, type) = readRaw(key) {
        let raw = (UInt16(bytes[0]) << 8) | UInt16(bytes[1])
        let rpm = Double(raw) / 4.0 // fpe2 format
        print("\(key): raw=\(bytes[0]),\(bytes[1]) type=\(type) -> \(rpm) RPM (fpe2 guess)")
    } else {
        print("\(key): brak odczytu")
    }
}
