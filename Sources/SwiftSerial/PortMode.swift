import Foundation

public enum PortMode {
	case receive
	case transmit
	case receiveAndTransmit

	var receive: Bool {
		switch self {
		case .receive:
			true
		case .transmit:
			false
		case .receiveAndTransmit:
			true
		}
	}

	var transmit: Bool {
		switch self {
		case .receive:
			false
		case .transmit:
			true
		case .receiveAndTransmit:
			true
		}
	}
}
