import Foundation

public struct PortError: RawRepresentable, Error, LocalizedError {

    public enum SwiftSerialError: Int32 {
        case mustBeOpen = 0
        case instanceAlreadyOpen = -1

        case internalInconsistency = -999
    }

    static let instanceAlreadyOpen = PortError(rawValue: SwiftSerialError.instanceAlreadyOpen.rawValue)
    static let mustBeOpen = PortError(rawValue: SwiftSerialError.mustBeOpen.rawValue)

    static let invalidPath = PortError(rawValue: ENOENT)
    static let timeout = PortError(rawValue: ETIMEDOUT)

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

        case .internalInconsistency:
            return "Internal inconsistency"
        case .none:
            return String(cString: strerror(rawValue))
        }
    }

}
