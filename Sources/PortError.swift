import Foundation

public enum PortError: Int32, Error {
	case failedToOpen = -1 // refer to open()
	case invalidPath
	case mustReceiveOrTransmit
	case mustBeOpen
	case stringsMustBeUTF8
	case unableToConvertByteToCharacter
	case deviceNotConnected
}
