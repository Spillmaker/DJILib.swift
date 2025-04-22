import Foundation
import CrcSwift

public class DJILib {
  
    public enum Model {
        case oa3
        case oa4
        case oa5pro
        case op3
    }
    
    public enum BroadcastResolution: Int, Codable {
        case sd = 480
        case hd = 720
        case fhd = 1080
    }
    
    public enum BroadcastEISMode: String, CaseIterable {
        case off = "Off"
        case rockSteady = "RockSteady"
        case rockSteadyPlus = "RockSteady +"
        case horizonBalancing = "HorizonBalancing"
        case horizonSteady = "HorizonSteady"
    }
    
    public enum Status {
        case unauthorized
        case authorized
    }
    
    public enum BroadcastStatus {
        case inactive
        case preparing
        case readyForWiFiCredentials
        case readyForRTMPCredentials
        case connecting
        case live
    }
    
    public struct Statistics: Identifiable {
        public var id = UUID()
        public var timeStamp: Date
        public var bitrate: Int?
        public var temperature: Double
        public var battery: Int
        
        public init(bitrate: Int?, temperature: Double, battery: Int){
            let calendar = Calendar.autoupdatingCurrent
            self.bitrate = bitrate
            self.timeStamp = calendar.date(from: calendar.dateComponents([.hour, .minute, .second], from: Date()))!
            self.temperature = temperature
            self.battery = battery
        }
    }
    
    
    /// DJi uses the two first bytes in the manufacturer-data to identify that it is a DJI-device.
    public static let manufacturerDataIdentifier: Data     = Data([0xAA, 0x08])
    
    public static let manufacturerDataOsmoAction3Id        = Data([0x12, 0x00])
    public static let manufacturerDataOsmoAction4Id        = Data([0x14, 0x00])
    public static let manufacturerDataOsmoAction5ProId     = Data([0x15, 0x00])
    public static let manufacturerDataOsmoPocket3Id        = Data([0x20, 0x00])
    
    
    
    
    public static let commandCharacteristicsUUID           = Data([0xFF, 0xF4])
    public static let dataCharacteristicsUUID              = Data([0xFF, 0xF5])
    
    public static let part_cmd_startbit                    = Data([0x55])
    
    var idBytes: Data = Data([0x00, 0x00])
    
    
    // Command Generator
    /// # Generate Payload
    /// This command constructs the full command based of the various parts, and then calculates the generated hashes and bytesums
    /// needed.
    /// - Parameters:
    ///     - command: DJI Commands are identified with their 2 Bytes ID. Note that responses flips the bytes, so for example if your
    ///     command is ``0x00, 0xFF``, the event that is a reply to that command would be ``0xFF, 0x00``
    ///     - id: Unique 2 bytes incremental ID for each message being sent to the device. You will find this id being used in the event that is a direct response to your command.
    ///     - type: Sort of a 3 bytes category for the command. This is often if not always linked to the command bytes
    ///          TODO: Make a comprehensible list of all avaliable categories
    ///   - data: The payload of the message. dynamic length
    func generateFullPayload(command: Data, id: Data, type: Data, data: Data) -> Data? {
        print("Sending dji command")
        
        guard command.count == 2 else {
            print("Command must be exactly 2 bits")
            return nil // Return nil if data does not have exactly 2 bytes
        }
        
        guard id.count == 2 else {
            print("ID must be exactly 2 bits")
            return nil // Return nil if data does not have exactly 2 bytes
        }
        
        guard type.count == 3 || type.count == 4 else {
            print("Type must be exactly 3 or 4 bits")
            return nil // Return nil if data does not have exactly 2 bytes
        }
        
        
        // [0]
        var fullData = Data(DJILib.part_cmd_startbit)
        
        // [1], which we generate at the end
        fullData.append(Data([0xFF]))
        
        // [2] - Spacer
        fullData.append(Data([0x04]))
        
        // [3] - crc8 Hash of the payload so far
        fullData.append(Data([0xFF]))
        
        // [4-5] - Command bits
        fullData.append(command)
        
        // [6-7] - ID bits? NO idea what they are
        fullData.append(id)
        
        // [8-10] - Type buts? No idea what they are
        fullData.append(type)
        
        // [11 - ??] - Main command
        fullData.append(Data(data)) // The main command
        
             
        // Generate [1] - Size bit
        let sizeBit = generateSizeBit(data: fullData)
        // Replace second bit in fullData
        fullData[1] = sizeBit[0]
        
        // Generate [3] cr8
        fullData[3] = djiCrc8(data: fullData[0 ... 2])[0]
        
        
        // Finalize with ending with a crc16 hash
        fullData.append(djiCrc16(data: fullData))
        
        print("Generated Full payload: \(fullData.hexEncodedString()) ")
        return fullData
    }
    
    private func getNextCountBits() -> Data{
        
        let nextBits = idBytes
        
        // Iterate
        if idBytes[0] == 0xFF {
            // If primary counter reached its max, reset and iterate on the next one instead
            idBytes[0] = 0x00
            idBytes[1] += 1
        } else {
            idBytes[0] += 1
        }
        
        print("Used countBits \(nextBits.hexEncodedString()). Next bits available is \(idBytes.hexEncodedString())")
        
        return nextBits
    }
    
    
    func stringToHexData(_ input: String) -> Data {
        return Data(input.utf8.map { $0 })
    }
    
    // Auth commands
    // This is withouht the pin code i think.
    public static let authCommand = Data([
        0x20, 0x32, 0x38, 0x34, 0x61, 0x65, 0x35, 0x62,
        0x38, 0x64, 0x37, 0x36, 0x62, 0x33, 0x33, 0x37,
        0x35, 0x61, 0x30, 0x34, 0x61, 0x36, 0x34, 0x31,
        0x37, 0x61, 0x64, 0x37, 0x31, 0x62, 0x65, 0x61,
        0x33, 0x04
    ])
    
    // THis is with A pin-code and the secundar command merged into one
    public static let authCommandOA5Prov2 = Data([
        0x20, 0x32, 0x38, 0x34, 0x61, 0x65, 0x35, 0x62,
        0x38, 0x64, 0x37, 0x36, 0x62, 0x33, 0x33, 0x37,
        0x35, 0x61, 0x30, 0x34, 0x61, 0x36, 0x34, 0x31,
        0x37, 0x61, 0x64, 0x37, 0x31, 0x62, 0x65, 0x61,
        0x33, 0x04, 0x37, 0x33, 0x32, 0x39, 0x77, 0xCE,
        0x55, 0x16, 0x04, 0xFC, 0x02, 0x48, 0x39, 0xAC,
        0x40, 0x00, 0x4F, 0x04, 0x00, 0x00, 0x00, 0x00,
        0xFF, 0xFF, 0xFF, 0xFF//, 0xD9, 0x0A
    ])
    
    // I have idea what thi sis.
    public static let authCommandOA5Pro = Data([
        0x0F, 0x30, 0x30, 0x31, 0x36, 0x37, 0x31, 0x39,
        0x31, 0x30, 0x36, 0x35, 0x36, 0x31, 0x34, 0x36,
        0x04
    ])
    
    // Authenticate-command
    
    /// Get the command to authenticate with the camera
    public func getAuthCommand(pin: String) -> Data{
        // TODO: Make function that can generate the generated bits
        // TODO: Strip the generated bits from the rawCommand
        // TODO: Inject the space (0x04) and the four bytes that is the pin
        // TODO: Stitch Together and recalculate hashes.
        //let rawCommand = Data([0x55, 0x33, 0x04, 0xC2, 0x02, 0x07, 0xA8, 0x94, 0x40, 0x07, 0x45, 0x20, 0x32, 0x38, 0x34, 0x61, 0x65, 0x35, 0x62, 0x38, 0x64, 0x37, 0x36, 0x62, 0x33, 0x33, 0x37, 0x35, 0x61, 0x30, 0x34, 0x61, 0x36, 0x34, 0x31, 0x37, 0x61, 0x64, 0x37, 0x31, 0x62, 0x65, 0x61, 0x33, 0x04, 0x38, 0x36, 0x37, 0x30, 0xB1, 0x88])
        
        
        let commandBytes = Data([0x02, 0x07])
        
        let idBytes = getNextCountBits()
        
        let typeBytes = Data([0x40, 0x07, 0x45])
        
        var dataBytes = Data([0x20, 0x32, 0x38, 0x34, 0x61, 0x65, 0x35, 0x62, 0x38, 0x64, 0x37, 0x36, 0x62, 0x33, 0x33, 0x37, 0x35, 0x61, 0x30, 0x34, 0x61, 0x36, 0x34, 0x31, 0x37, 0x61, 0x64, 0x37, 0x31, 0x62, 0x65, 0x61, 0x33, 0x04])
        
        dataBytes.append(stringToHexData(pin))
        
        let fullPayload = generateFullPayload(command: commandBytes, id: idBytes, type: typeBytes, data: dataBytes)
        
        return fullPayload!
    }
    
    // Broadcast-commands
    
    /// # Set Broadcast state command
    ///
    /// Required for DJI Osmo Action 5 Pro to be sent after WiFi, RTMP and Preferences commands to successfully start the broadcast.
    /// ### Category
    /// 02 08 - Broadcast command
    /// ### Subcategory
    /// **40 02 8E - Unknown Broadcast configure command**
    /// It is assumed that this subcategory is unique for this command, in that it is a confirmation for the camera that all settings have been inputted and it can proceed to start the broadcast.
    ///
    /// ## Command bits
    /// - 11 - Does not work to start the stream if set to anything else than 01
    /// - 12 - Does not work to start the stream if set to anything else than 01
    /// - 13 - Does not work to start the stream if set to anything else than 1A
    /// - 14 - Does not work to start the stream if set to anything else than 1A
    /// - 15 - Can be modified but nothing apparenty changes
    /// - 16 - Set Stream state
    ///   - 1  Start Stream (Default)
    ///   - 2  Stop/Cancel Stream
    static let set_broadcast_command = Data([
        0x55, 0x13, 0x04, 0x03, 0x02, 0x08, 0x6A, 0xC0,
        0x40, 0x02, 0x8E, 0x01, 0x01, 0x1A, 0x00, 0x01,
        0x01
    ]) //0x68, 0x6D
    
    
    public func get_start_broadcast_command() -> Data {
        return updateChecksumBits(payload: DJILib.set_broadcast_command)
    }
    
    public func get_initiate_broadcast_command() -> Data {
        return Data([0x55, 0x0E, 0x04, 0x66, 0x02, 0x08, 0x12, 0x8C, 0x40, 0x02, 0xE1, 0x1A, 0x11, 0xDF])
    }
    
    public func get_stop_broadcast_command() -> Data {
        var stopCommand = DJILib.set_broadcast_command
        stopCommand[16] = 0x02
        return updateChecksumBits(payload: stopCommand)
    }
    
    private func getBitrateHexes(bitrate: Int) -> Data{
        let highByte = UInt8((bitrate >> 8) & 0xFF)
        let lowByte = UInt8(bitrate & 0xFF)
            
        return Data([highByte, lowByte])
    }
    
    private func getCountDataBit(_ data: Data) -> Data {
        return Data([UInt8(data.count)])
    }
    
    public func getWiFiConfigurationCommand(ssid: String, password: String) -> Data{
        
        print("ssid \(ssid) Password: \(password)")
        

        var message: Data = Data()
        message.append(getCountDataBit(ssid.data(using: .utf8)!)) // The length of the SSID
        message.append(Data(ssid.data(using: .utf8)!)) // The SSID
        message.append(getCountDataBit(password.data(using: .utf8)!)) //The Length of the password
        message.append(Data(password.data(using: .utf8)!))
        
        let payload = generateFullPayload(
            command: Data([0x02, 0x07]),
            id: Data([0xB2, 0xEA]),
            type: Data([0x40, 0x07, 0x47]),
            data: message
        )
        Logger.log("Sending WiFi credentials to camera: \(payload?.hexEncodedString() ?? "No Data") ", level: .info)
        return payload!
    }
    
    
    public func getRTMPConfigCommand(rtmpURL: String, bitrate: Int, resolution: DJILib.BroadcastResolution, fps: Int, auto: Bool, eis: DJILib.BroadcastEISMode) -> Data{
        
        // Two first bits unknown, Next 5 is Stream settings. Rest us currently unknown
        _ = Data([0x27, 0x00, 0x0A, 0x70, 0x17, 0x02, 0x00, 0x03, 0x00, 0x00, 0x00, 0x1C, 0x00])
        var message = Data([0x27, 0x00, 0x04, 0xA0, 0x0F, 0x02, 0x01, 0x03, 0x00, 0x00, 0x00, 0x1C, 0x00])
        message.append(Data(rtmpURL.data(using: .utf8)!))
        
        // Get hex length of rtmpUrl
        let rtmpUrlByteCount = UInt8(rtmpURL.data(using: .utf8)?.count ?? 0)
        
        message[11] = UInt8(rtmpUrlByteCount)
                
        // Bitrate
        let bitrateData = getBitrateHexes(bitrate: bitrate)
        message[4] = bitrateData[0]
        message[5] = bitrateData[1]
        
        // 7 - Framerate
        // TODO: Convert number to hex
        if(fps == 25){
            message[7] = 0x02 // 30fps TODO: s
        }
        if(fps == 30){
            message[7] = 0x03 // 30fps TODO: s
        }
    
        if(fps == 60){
            message[7] = 0x06 // 30fps TODO: s
        }
        
        //Resolution
        switch(resolution){
        case .sd:
            message[2] = 0x47
            break;
        case .hd:
            message[2] = 0x04
            break;
        case .fhd:
            message[2] = 0x0A
            break;
        }
        
        
        // Quality is Resolution + Bitrate so we dont need that
        
        // Define whetever "Auto" should be on or off.
        message[6] = auto ? 0x01 : 0x00
        var payload = generateFullPayload(
            command: Data([0x02, 0x08]),
            id: Data([0xBE, 0xEA]),
            type: Data([0x40, 0x08, 0x78, 0x00]),
            data: message
        )
        
        // Append with the secondary EIS messaeg
        // EIS
        var eisMessage = Data([0x01, 0x01, 0x08, 0x00, 0x01, 0x02, 0xF0, 0x72])
        switch(eis){
        case .off:
            eisMessage[5] = 0x00
            break;
        case .rockSteady:
            eisMessage[5] = 0x01
            break;
        case .rockSteadyPlus:
            eisMessage[5] = 0x03
            break;
        case .horizonBalancing:
            eisMessage[5] = 0x04
            break;
        case .horizonSteady:
            eisMessage[5] = 0x02
            break;
        }
        let eisPayload = generateFullPayload(
            command: Data([0x02, 0x01]),
            id: getNextCountBits(),
            type: Data([0x40, 0x02, 0x8E]),
            data: eisMessage
        )
        
        Logger.log("Generated secondary (EIS) Livestream-command: \(eisPayload?.hexEncodedString() ?? "No Data")", level: .info)
        payload?.append(eisPayload!)
        

        
        let updatedCommandDemo = get_start_broadcast_command()
        Logger.log("Generated Third livestream-command needed for OA5P: \(updatedCommandDemo.hexEncodedString())", level: .info)

        payload?.append(updatedCommandDemo)
        Logger.log("Generated full Livestream-command: \(payload?.hexEncodedString() ?? "No Data")", level: .info)

        return payload!
    }
    
    private static func log(_ items: Any..., separator: String = " ", terminator: String = "\n") {
        let prefix = "🔹 "
        let message = items.map { String(describing: $0) }.joined(separator: separator)
        Swift.print(prefix + message, terminator: terminator)
    }

    public init(){
        print("DJILIB Initiated")
    }
    
    public static func getModelFromManufacturerData(manufacturerData: Data) -> Model? {
        
        guard manufacturerData.count >= 4 else {
            log("Recieved invalid manufacturer-data")
            return nil
        }
        
        guard manufacturerData[0 ... 1] == manufacturerDataIdentifier else {
            log("Manufacturer-data not identified as a DJI-device.")
            return nil
        }
        
        switch manufacturerData[2 ... 3] {
        case manufacturerDataOsmoAction3Id:
            return .oa3
        case manufacturerDataOsmoAction4Id:
            return .oa4
        case manufacturerDataOsmoAction5ProId:
            return .oa5pro
        case manufacturerDataOsmoPocket3Id:
            return .op3
        default:
            log("Could not idenfity DJI-device", manufacturerData)
            return nil
        }
        

    }
 
    
    func updateChecksumBits(payload: Data) -> Data {
        print("DJILIB - Original payload is: \(payload.hexEncodedString()) ")
        var updatedPayload = payload
        // Set Size-bit
        updatedPayload[1] = generateSizeBit(data: payload)[0]
        
        // Generate cr8 checksum
        updatedPayload[3] = djiCrc8(data: updatedPayload[0 ... 2])[0]
        
        // Generate end hashes
        let endChecksums = djiCrc16(data: updatedPayload)
        updatedPayload.append(endChecksums)
        
        //0x68, 0x6D
        
        print("DJILIB - Updated payload is: \(updatedPayload.hexEncodedString()) ")
        return updatedPayload
        
    }
    
    
    private func djiCrc8(data: Data) -> Data {
        let crc8 = CrcSwift.computeCrc8(
            data,
            initialCrc: 0xEE,
            polynom: 0x31,
            xor: 0x00,
            refIn: true,
            refOut: true
        )
        
        return Data([crc8])
    }

    private func djiCrc16(data: Data) -> Data {
        let crc16 = CrcSwift.computeCrc16(
            data,
            initialCrc: 0x496C,
            polynom: 0x1021,
            xor: 0x0000,
            refIn: true,
            refOut: true
        )
        let hashData = Data([UInt8(crc16 & 0xFF), UInt8((crc16 >> 8) & 0xFF)])
        return hashData
    }
    
    private func generateSizeBit(data: Data) -> Data{
        // Return a Data object containing the hex of the length of fullCommand
        let size = data.count + 2 // We add to to make sure we count the not yet added crc bits
        return Data([UInt8(size)])
    }
    
    
    
    public protocol Message {
        var rawData: Data {get set}
    }
    
    public struct AuthEvent : Message {
        public var rawData: Data
        public var isAuthenticated: Bool
        
        public init(rawData: Data, isAuthenticated: Bool) {
            self.rawData = rawData
            self.isAuthenticated = isAuthenticated
        }
    }
    
    public struct BroadcastEvent: Message {
        public var rawData: Data
        public var status: BroadcastStatus = .preparing
        
        public init(rawData: Data, status: BroadcastStatus) {
            self.rawData = rawData
            self.status = status
        }
    }
    
    public struct StatusEvent: Message {
        public var rawData: Data
    }
    
    public struct UnknownEvent : Message {
        public var rawData: Data
        
        public init(rawData:Data){
            self.rawData = rawData
        }
    }
    
    public struct StatisticsMessage: Message {
        public var rawData: Data
        public var bitrate: Int?
        public var temperature: Double
        public var battery: Int
        
        public init(rawData: Data, bitrate: Int? = nil, temperature: Double, battery: Int) {
            self.rawData = rawData
            self.bitrate = bitrate
            self.temperature = temperature
            self.battery = battery
        }
        
    }
    
    public struct WifiListEvent : Message {
        public var rawData: Data
        public var wifiStatus: WiFiStatus?
        public var wifiItems: [WiFiItem]

        public struct WiFiItem{
            public var ssid: String
            public var band: WiFiBand
            
            public init(ssid: String, band: WiFiBand) {
                self.ssid = ssid
                self.band = band
            }
        }
        
        public enum WiFiBand {
            case _2_4GHz
            case _5GHz
        }
        
        public enum WiFiStatus {
            case connected
            case connectionFailed
        }
        
        public init(rawData: Data, wifiStatus: WiFiStatus? = nil, wifiItems: [WiFiItem]) {
            self.rawData = rawData
            self.wifiStatus = wifiStatus
            self.wifiItems = wifiItems
        }
        
    }
    
    public func parseNotifyMessage(_ data: Data, model: Model) -> Message{
        
        // If the payload is not large enough to parse a message, return unknown event.
        guard data.count >= 6 else {
            return UnknownEvent(rawData: data)
        }
        
        // Unmapped command: 0x01, 0x02
        if(data[4] == 0x01 && data[5] == 0x02){
            return DJILib.UnknownEvent(rawData: data)
        }
        
        // Command: Camera Status
        if(data[4] == 0x05 && data[5] == 0x02){
            
            // Plot bit 12 and 13 to something. (Not bitrate.)
            let bitrate = Int( twoBitsToDecimal(bits: [ data[12], data[13] ]) )
            
            let temperature = Double(twoBitsToDecimal(bits: [data[28], data[29]] ) / 10)
            
            let battery = Int(data[31])

            return DJILib.StatisticsMessage(
                rawData: data,
                bitrate: bitrate,
                temperature: temperature,
                battery: battery
            )
        }
        
        // Command: Authorization
        if(data[4] == 0x07 && data[5] == 0x02){
            
            // Subcommand: Pairing
            if(data[9] == 0x07 && data[10] == 0x45){

                // Pairing allready done. Authorized.
                if(data[11] == 0x00 && data[12] == 0x01){
                    return DJILib.AuthEvent(rawData: data, isAuthenticated: true)
                }
                
                // Pairing missing. Requesting pairing from user. Unauthorized
                if(data[11] == 0x00 && data[12] == 0x02){
                    // Unauthorized. (User will se the pin-code)
                    return DJILib.AuthEvent(rawData: data, isAuthenticated: false)
                }
                
                // Pairing approved by user. Authorized.
                if(data[11] == 0x01 && data[12] == 0x10) {
                    // User approved the pin-code, and we are now authenticated
                    return DJILib.AuthEvent(rawData: data, isAuthenticated: true)
                }
                Logger.log("Unknown Pairing response", level: .warning)
                
            }
            
            // Type: Event whenever user has approved the auth
            if(data[9] == 0x07 && data[10] == 0x46){
                
                if(data[11] == 0x01){
                    return DJILib.AuthEvent(rawData: data, isAuthenticated: true)
                }
                
                if(data[11] == 0x00){
                    return DJILib.AuthEvent(rawData: data, isAuthenticated: false)
                }
                
                // TODO: 02 - Connection timed out
                if(data[11] == 0x02){
                    return DJILib.AuthEvent(rawData: data, isAuthenticated: false)
                }
                // Pairing has been validated.
                Logger.log("Unknown Auth event response", level: .warning)
            }
            
            // Type: Wireless SSID entry result
            if(data[9] == 0x07 && data[10] == 0x47){
                if(data[11] == 0x00){
                    //print("Connected to WiFi")
                    return DJILib.WifiListEvent(rawData: data, wifiStatus: .connected, wifiItems: [])
                }
                
                if(data[11] == 0x01){
                    //print("Could not connect to wifi")
                    return DJILib.WifiListEvent(rawData: data, wifiStatus: .connectionFailed, wifiItems: [])
                }
                
            }
            
            // Type: Wireless network
            if(data[9] == 0x07 && data[10] == 0xAC){
                // Since we have recieved the WiFi List payload, we can now say that we are ready for credentials
                return parseWifiListMessage(data: data, model: model)!
            }
            

            
        }
        
        // Category (Command): Livestream
        if(data[4] == 0x08 && data[5] == 0x02){
            
            // Broadcast mode enabled confirmation
            if(data[9] == 0x02 && data[10] == 0xE1){
                // This is a response to sending the start broadcast command.
                return DJILib.BroadcastEvent(rawData: data, status: .preparing)
            }
            
            if(data[9] == 0xee && data[10] == 0x03){
                // This is a response to sending the start broadcast command.
                print("Broadcast-event update: \(data.subdata(in: 9..<11).hexEncodedString())")
                print("Full payload: " + data.hexEncodedString())
                
                // If data[12] is 0x09, the camera is in start broadcasting mode, and we can proceed to
                // send in wifi-credentials
                if(data[12] == 0x09){
                    return DJILib.BroadcastEvent(rawData: data, status: .readyForWiFiCredentials)
                }
                
                return DJILib.UnknownEvent(rawData: data)
            }
            
        }
        
        if(data[4] == 0x28 && data[5] == 0x02){
            return DJILib.UnknownEvent(rawData: data)
        }

        
        // Category (Command): Unknown
        if(data[4] == 0x48 && data[5] == 0x02){
            return DJILib.UnknownEvent(rawData: data)
        }
        
        
        
        return DJILib.UnknownEvent(rawData: data)
    }
    
    
    func parseWifiListMessage(data: Data, model: Model) -> DJILib.WifiListEvent?{
        
        guard data[0] == 0x55 else {
            print("[DJIDevice] Invalid message type. Must be full event from the camera.")
            return nil
        }
        
        guard data[4] == 0x07 && data[5] == 0x02 else {
            print("[DJIDevice] Invalid message type. Must be of category wifi (0x07 0x02)")
            return nil
        }
        
        guard model != .oa5pro else {
            return DJILib.WifiListEvent(rawData: data, wifiItems: [])
            // TODO: Add parsing for oa5pro here. it seems to be different for some reason.
        }

        var wifiDataItems: [Data] = []
        
        var bitCounter = 14 // We ignore the first 14 bits
        for i in 0..<data.count - 2 {
            if i <= bitCounter { continue }
            
            // Get first bit as data-object
            let bitData = data.subdata(in: i..<i+1)
            let itemLength = Int(bitData[0]) // The length of the item.
            
            // Append to array.
            wifiDataItems.append(data.subdata(in: i..<i+itemLength))

            bitCounter += itemLength
        }
        
        // We now have a nice data-array to deal with.
        var wifiListMessage = DJILib.WifiListEvent(
            rawData: data,
            wifiItems: [])
        for wifiItem in wifiDataItems {
            
            let band: DJILib.WifiListEvent.WiFiBand
            if wifiItem[4] == 0x01 {
                band = ._5GHz
            }else if wifiItem[4] == 0x00 {
                band = ._2_4GHz
            } else {
                print("Unknown band")
                return nil
            }
            
            
            
            let ssidData = wifiItem.subdata(in: 6..<wifiItem.count);
            let ssid = String(data: ssidData, encoding: .utf8)!
            
            wifiListMessage.wifiItems.append(
                DJILib.WifiListEvent.WiFiItem(
                ssid: ssid,
                band: band
                )
            )
        }
 
        
        return wifiListMessage
    }
    
    
    
    private func twoBitsToDecimal(bits: [UInt8]) -> UInt16 {
        // Ensure we have at least two bytes in the array
        guard bits.count >= 2 else {
            print("Error: Not enough bytes provided")
            return 0
        }
        
        // Convert the two bytes to UInt16 and perform the calculation
        let result = UInt16(bits[0]) + (UInt16(bits[1]) * 255)
        
        return result
    }
    
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
