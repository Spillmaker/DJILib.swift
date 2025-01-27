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
