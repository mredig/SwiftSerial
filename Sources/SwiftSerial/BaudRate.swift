import Foundation

public enum BaudRate {
	case baud0
	case baud50
	case baud75
	case baud110
	case baud134
	case baud150
	case baud200
	case baud300
	case baud600
	case baud1200
	case baud1800
	case baud2400
	case baud4800
	case baud9600
	case baud19200
	case baud38400
	case baud57600
	case baud115200
	case baud230400
	#if os(Linux)
	case baud460800
	case baud500000
	case baud576000
	case baud921600
	case baud1000000
	case baud1152000
	case baud1500000
	case baud2000000
	case baud2500000
	case baud3500000
	case baud4000000
	#endif

	public init(_ value: UInt) throws {
		switch value {
		case 0:
			self = .baud0
		case 50:
			self = .baud50
		case 75:
			self = .baud75
		case 110:
			self = .baud110
		case 134:
			self = .baud134
		case 150:
			self = .baud150
		case 200:
			self = .baud200
		case 300:
			self = .baud300
		case 600:
			self = .baud600
		case 1200:
			self = .baud1200
		case 1800:
			self = .baud1800
		case 2400:
			self = .baud2400
		case 4800:
			self = .baud4800
		case 9600:
			self = .baud9600
		case 19200:
			self = .baud19200
		case 38400:
			self = .baud38400
		case 57600:
			self = .baud57600
		case 115200:
			self = .baud115200
		case 230400:
			self = .baud230400
		#if os(Linux)
		case 460800:
			self = .baud460800
		case 500000:
			self = .baud500000
		case 576000:
			self = .baud576000
		case 921600:
			self = .baud921600
		case 1000000:
			self = .baud1000000
		case 1152000:
			self = .baud1152000
		case 1500000:
			self = .baud1500000
		case 2000000:
			self = .baud2000000
		case 2500000:
			self = .baud2500000
		case 3500000:
			self = .baud3500000
		case 4000000:
			self = .baud4000000
		#endif
		default:
			throw PortError.invalidPort
		}
	}

	var speedValue: speed_t {
		switch self {
		case .baud0:
			return speed_t(B0)
		case .baud50:
			return speed_t(B50)
		case .baud75:
			return speed_t(B75)
		case .baud110:
			return speed_t(B110)
		case .baud134:
			return speed_t(B134)
		case .baud150:
			return speed_t(B150)
		case .baud200:
			return speed_t(B200)
		case .baud300:
			return speed_t(B300)
		case .baud600:
			return speed_t(B600)
		case .baud1200:
			return speed_t(B1200)
		case .baud1800:
			return speed_t(B1800)
		case .baud2400:
			return speed_t(B2400)
		case .baud4800:
			return speed_t(B4800)
		case .baud9600:
			return speed_t(B9600)
		case .baud19200:
			return speed_t(B19200)
		case .baud38400:
			return speed_t(B38400)
		case .baud57600:
			return speed_t(B57600)
		case .baud115200:
			return speed_t(B115200)
		case .baud230400:
			return speed_t(B230400)
		#if os(Linux)
		case .baud460800:
			return speed_t(B460800)
		case .baud500000:
			return speed_t(B500000)
		case .baud576000:
			return speed_t(B576000)
		case .baud921600:
			return speed_t(B921600)
		case .baud1000000:
			return speed_t(B1000000)
		case .baud1152000:
			return speed_t(B1152000)
		case .baud1500000:
			return speed_t(B1500000)
		case .baud2000000:
			return speed_t(B2000000)
		case .baud2500000:
			return speed_t(B2500000)
		case .baud3500000:
			return speed_t(B3500000)
		case .baud4000000:
			return speed_t(B4000000)
		#endif
		}
	}
}
