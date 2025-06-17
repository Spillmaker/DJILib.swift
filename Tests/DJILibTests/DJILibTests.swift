import Testing
import Foundation
@testable import DJILib

@Test func example() async throws {
    // Write your test here and use APIs like `#expect(...)` to check expected conditions.
}

@Test func manufacturerDataCheck() async throws {
    
    // Test invalid manufacturerdata (Too short)
    #expect( DJILib.getModelFromManufacturerData(manufacturerData: Data([0xFF]) ) == nil)
    
    
    // Test "random" data
    #expect( DJILib.getModelFromManufacturerData(manufacturerData: Data([0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF]) ) == nil)
    
    // Test valid DJI, but invalid rest.
    #expect( DJILib.getModelFromManufacturerData(manufacturerData: Data([0xAA, 0x08, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF]) ) == nil)
    
    // Test valid Osmo Pocket 3
    #expect( DJILib.getModelFromManufacturerData(manufacturerData: Data([0xAA, 0x08, 0x12, 0x00]) ) == .oa3)
    #expect( DJILib.getModelFromManufacturerData(manufacturerData: Data([0xAA, 0x08, 0x14, 0x00]) ) == .oa4)
    #expect( DJILib.getModelFromManufacturerData(manufacturerData: Data([0xAA, 0x08, 0x15, 0x00]) ) == .oa5pro)
    #expect( DJILib.getModelFromManufacturerData(manufacturerData: Data([0xAA, 0x08, 0x20, 0x00]) ) == .op3)
    
}

@Test func rtmpUrlByteLengthCheck() async throws {
    let rtmpTest = DJILib.getRTMPConfigCommand(
        rtmpURL: "rtmp://192.168.1.123/publish/live/a/test", // should expect 0x28 in response base on this URL.
        bitrate: 3000,
        resolution: .fhd,
        fps: 30,
        auto: false,
        eis: .rockSteady,
        countBit: Data([0x00,0x00])
    )
    
    
    #expect(rtmpTest[23] == 0x28)
    
    print(rtmpTest.hexEncodedString())
}



extension Data {
    struct HexEncodingOptions: OptionSet {
        let rawValue: Int
        static let upperCase = HexEncodingOptions(rawValue: 1 << 0)
    }

    func hexEncodedString(options: HexEncodingOptions = []) -> String {
        let format = options.contains(.upperCase) ? "%02hhX" : "%02hhx"
        return self.map { String(format: format, $0) }.joined(separator: " ")
    }
}
