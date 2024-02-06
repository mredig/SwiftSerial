import Foundation

public struct PortError: RawRepresentable, Error, LocalizedError {

    public enum SwiftSerialError: Int32 {
        case mustBeOpen = 0
        case instanceAlreadyOpen = -1

        case unableToConvertByteToCharacter = -997
        case stringsMustBeUTF8 = -998
        case internalInconsistency = -999
    }

    static let instanceAlreadyOpen = PortError(rawValue: SwiftSerialError.instanceAlreadyOpen.rawValue)
    static let mustBeOpen = PortError(rawValue: SwiftSerialError.mustBeOpen.rawValue)

    static let invalidPath = PortError(rawValue: ENOENT)
    static let timeout = PortError(rawValue: ETIMEDOUT)

    static let stringsMustBeUTF8 = PortError(rawValue: SwiftSerialError.stringsMustBeUTF8.rawValue)
    static let unableToConvertByteToCharacter = PortError(rawValue: SwiftSerialError.unableToConvertByteToCharacter.rawValue)

    static let internalInconsistency = PortError(rawValue: SwiftSerialError.internalInconsistency.rawValue)

    public let rawValue: Int32

    public init(rawValue: Int32) {
        self.rawValue = rawValue
    }

    public var errorDescription: String? {
        switch SwiftSerialError(rawValue: rawValue) {
        case .instanceAlreadyOpen:
            return "SerialPort is already open"
        case .mustBeOpen:
            return "SerialPort must be open"

        case .unableToConvertByteToCharacter:
            return "unable to convert byte to character"
        case .stringsMustBeUTF8:
            return "Strings must be in UTF-8 encoding"

        case .internalInconsistency:
            return "Internal inconsistency"

        case .none:
            return String(cString: strerror(rawValue))
        }
    }

}
