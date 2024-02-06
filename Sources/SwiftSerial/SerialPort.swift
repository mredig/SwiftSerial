#if canImport(Darwin)
import Darwin
#endif
import Foundation

public class SerialPort {

	let path: String
	private(set) var fileDescriptor: Int32?

	private var isOpen: Bool { fileDescriptor != nil }

	private var pollSource: DispatchSourceRead?
	private var readDataStream: AsyncStream<Data>?
	private var readBytesStream: AsyncStream<UInt8>?
	private var readLinesStream: AsyncStream<String>?
    private var timeout: Int = 0

	private let lock = NSLock()

	public init(path: String) {
		self.path = path
	}

    /**
     Open a serial port with provided flags

     - Parameter portMode: POSIX [open()](https://linux.die.net/man/2/open) flags
        Wraps posix file open flags such as `O_RDWR`, `O_RDWR` and others
        Can be initialized directly with POSIX flags using `PortMode(rawValue:)`
        The default value is `.receiveAndTransmit` which matches `O_RDWR | O_NOCTTY | O_EXLOCK` on macOS or `O_RDWR | O_NOCTTY`on linux

     - Throws:
       An error of type `PortError`. Can be `.invalidPath` or other `OSError errno` wrapped by `PortError.rawValue`. The error provides `localizedDescription`.
     */
	public func openPort(portMode: PortMode = .receiveAndTransmit) throws {
		lock.lock()
		defer { lock.unlock() }
		guard isOpen == false else { throw PortError.instanceAlreadyOpen }

        fileDescriptor = open(path, portMode.rawValue)

		// Throw error if open() failed
		guard let fileDescriptor, fileDescriptor >= 0 else { throw PortError(rawValue: errno) }

        // portMode should contain Read
        guard portMode.contains(.readOnly) else { return }

		let pollSource = DispatchSource.makeReadSource(fileDescriptor: fileDescriptor, queue: .global(qos: .default))
		let stream = AsyncStream<Data> { continuation in
			pollSource.setEventHandler { [lock] in
				lock.lock()
				defer { lock.unlock() }

				let bufferSize = 1024
				let buffer = UnsafeMutableRawPointer
					.allocate(byteCount: bufferSize, alignment: 8)
				let bytesRead = read(fileDescriptor, buffer, bufferSize)
				guard bytesRead > 0 else { return }
				let bytes = Data(bytes: buffer, count: bytesRead)
				continuation.yield(bytes)
			}

			pollSource.setCancelHandler {
				continuation.finish()
			}
		}
		pollSource.resume()
		self.pollSource = pollSource
		self.readDataStream = stream
	}

	public struct BaudRateSetting {
		public let receiveRate: BaudRate
		public let transmitRate: BaudRate

		public init(receiveRate: BaudRate, transmitRate: BaudRate) {
			self.receiveRate = receiveRate
			self.transmitRate = transmitRate
		}

		public static func symmetrical(_ baudRate: BaudRate) -> BaudRateSetting {
			Self(receiveRate: baudRate, transmitRate: baudRate)
		}

		public static func asymmetrical(receiveRate: BaudRate, transmitRate: BaudRate) -> BaudRateSetting {
			Self(receiveRate: receiveRate, transmitRate: transmitRate)
		}
	}

    /**
      Sets the communication settings for the serial port.

      - Parameters:
        - baudRateSetting: The desired baud rate setting for the serial port.
        - minimumBytesToRead: The minimum number of bytes to read before returning from a [read()](https://linux.die.net/man/2/read) operation.
        - timeout: The inter-character timer value in tenths of a second. A value of 0 means wait indefinitely.
        - parityType: The type of parity to use for error checking during communication. Default is no parity.
        - sendTwoStopBits: A Boolean value indicating whether to send two stop bits. Default is false (one stop bit).
        - dataBitsSize: The number of data bits in each character. Default is 8 bits.
        - useHardwareFlowControl: A Boolean value indicating whether to use hardware flow control. Default is false.
        - useSoftwareFlowControl: A Boolean value indicating whether to use software flow control. Default is false.
        - processOutput: A Boolean value indicating whether to process output. Default is false.

      - Throws:
        An error of type `PortError`. Can be `.mustBeOpen` or other `OSError errno` wrapped by `PortError.rawValue`. The error provides `localizedDescription`.

      - Note:
        The `timeout` parameter specifies the inter-character timer value in tenths of a second.
        A value of 0 means wait indefinitely for input.
        A value of 10 means that the read operation will block until at least one character is received, or the timer expires after 1 second

        Usage:
        ```
        serialPort.setSettings(receiveRate: .baud9600, transmitRate: .baud9600, minimumBytesToRead: 1)
        ```

        The port settings call can be as simple as the above. For the baud rate, just supply both transmit and receive even if you are only intending to use one transfer direction. For example, transmitRate will be ignored if you specified     `andTransmit : false` when opening the port.

      - SeeAlso: `BaudRateSetting`, `ParityType`, `DataBitsSize`, `PortError`
     */
	public func setSettings(
		baudRateSetting: BaudRateSetting,
		minimumBytesToRead: Int,
		timeout: Int = 0, /* 0 means wait indefinitely */
		parityType: ParityType = .none,
		sendTwoStopBits: Bool = false, /* 1 stop bit is the default */
		dataBitsSize: DataBitsSize = .bits8,
		useHardwareFlowControl: Bool = false,
		useSoftwareFlowControl: Bool = false,
		processOutput: Bool = false
	) throws {
		lock.lock()
		defer { lock.unlock() }
		guard let fileDescriptor = fileDescriptor else {
			throw PortError.mustBeOpen
		}

		// Set up the control structure
		var settings = termios()

		// Get options structure for the port
        guard tcgetattr(fileDescriptor, &settings) == 0 else { throw PortError(rawValue: errno) }

		// Set baud rates
		cfsetispeed(&settings, baudRateSetting.receiveRate.speedValue)
		cfsetospeed(&settings, baudRateSetting.transmitRate.speedValue)
        self.timeout = timeout

		// Enable parity (even/odd) if needed
		settings.c_cflag |= parityType.parityValue

		// Set stop bit flag
		if sendTwoStopBits {
			settings.c_cflag |= tcflag_t(CSTOPB)
		} else {
			settings.c_cflag &= ~tcflag_t(CSTOPB)
		}

		// Set data bits size flag
		settings.c_cflag &= ~tcflag_t(CSIZE)
		settings.c_cflag |= dataBitsSize.flagValue

		//Disable input mapping of CR to NL, mapping of NL into CR, and ignoring CR
		settings.c_iflag &= ~tcflag_t(ICRNL | INLCR | IGNCR)

		// Set hardware flow control flag
		#if os(Linux)
		if useHardwareFlowControl {
			settings.c_cflag |= tcflag_t(CRTSCTS)
		} else {
			settings.c_cflag &= ~tcflag_t(CRTSCTS)
		}
		#elseif os(OSX)
		if useHardwareFlowControl {
			settings.c_cflag |= tcflag_t(CRTS_IFLOW)
			settings.c_cflag |= tcflag_t(CCTS_OFLOW)
		} else {
			settings.c_cflag &= ~tcflag_t(CRTS_IFLOW)
			settings.c_cflag &= ~tcflag_t(CCTS_OFLOW)
		}
		#endif

		// Set software flow control flags
		let softwareFlowControlFlags = tcflag_t(IXON | IXOFF | IXANY)
		if useSoftwareFlowControl {
			settings.c_iflag |= softwareFlowControlFlags
		} else {
			settings.c_iflag &= ~softwareFlowControlFlags
		}

		// Turn on the receiver of the serial port, and ignore modem control lines
		settings.c_cflag |= tcflag_t(CREAD | CLOCAL)

		// Turn off canonical mode
		settings.c_lflag &= ~tcflag_t(ICANON | ECHO | ECHOE | ISIG)

		// Set output processing flag
		if processOutput {
			settings.c_oflag |= tcflag_t(OPOST)
		} else {
			settings.c_oflag &= ~tcflag_t(OPOST)
		}

		//Special characters
		//We do this as c_cc is a C-fixed array which is imported as a tuple in Swift.
		//To avoid hardcoding the VMIN or VTIME value to access the tuple value, we use the typealias instead
		#if os(Linux)
		typealias specialCharactersTuple = (VINTR: cc_t, VQUIT: cc_t, VERASE: cc_t, VKILL: cc_t, VEOF: cc_t, VTIME: cc_t, VMIN: cc_t, VSWTC: cc_t, VSTART: cc_t, VSTOP: cc_t, VSUSP: cc_t, VEOL: cc_t, VREPRINT: cc_t, VDISCARD: cc_t, VWERASE: cc_t, VLNEXT: cc_t, VEOL2: cc_t, spare1: cc_t, spare2: cc_t, spare3: cc_t, spare4: cc_t, spare5: cc_t, spare6: cc_t, spare7: cc_t, spare8: cc_t, spare9: cc_t, spare10: cc_t, spare11: cc_t, spare12: cc_t, spare13: cc_t, spare14: cc_t, spare15: cc_t)
		var specialCharacters: specialCharactersTuple = (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0) // NCCS = 32
		#elseif os(OSX)
		typealias specialCharactersTuple = (VEOF: cc_t, VEOL: cc_t, VEOL2: cc_t, VERASE: cc_t, VWERASE: cc_t, VKILL: cc_t, VREPRINT: cc_t, spare1: cc_t, VINTR: cc_t, VQUIT: cc_t, VSUSP: cc_t, VDSUSP: cc_t, VSTART: cc_t, VSTOP: cc_t, VLNEXT: cc_t, VDISCARD: cc_t, VMIN: cc_t, VTIME: cc_t, VSTATUS: cc_t, spare: cc_t)
		var specialCharacters: specialCharactersTuple = (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0) // NCCS = 20
		#endif

		specialCharacters.VMIN = cc_t(minimumBytesToRead)
		specialCharacters.VTIME = cc_t(timeout)
		settings.c_cc = specialCharacters

		// Commit settings
		tcsetattr(fileDescriptor, TCSANOW, &settings)
	}

	public func closePort() {
		lock.lock()
		defer { lock.unlock() }
		pollSource?.cancel()
		pollSource = nil

		readDataStream = nil
		readBytesStream = nil
		readLinesStream = nil

		if let fileDescriptor = fileDescriptor {
			close(fileDescriptor)
		}
		fileDescriptor = nil
	}
}

// MARK: Receiving
extension SerialPort {
	public func asyncData() throws -> AsyncStream<Data> {
		guard
			isOpen,
			let readDataStream
		else {
			throw PortError.mustBeOpen
		}

		return readDataStream
	}

	public func asyncBytes() throws -> AsyncStream<UInt8> {
		guard
			isOpen,
			let readDataStream
		else {
			throw PortError.mustBeOpen
		}

		if let existing = readBytesStream {
			return existing
		} else {
			let new = AsyncStream<UInt8> { continuation in
				Task {
					for try await data in readDataStream {
						for byte in data {
							continuation.yield(byte)
						}
					}
					continuation.finish()
				}
			}
			readBytesStream = new
			return new
		}
	}

	public func asyncLines() throws -> AsyncStream<String> {
		guard isOpen else { throw PortError.mustBeOpen }

		if let existing = readLinesStream {
			return existing
		} else {
			let byteStream = try asyncBytes()
			let new = AsyncStream<String> { continuation in
				Task {
					var accumulator = Data()
					for try await byte in byteStream {
						accumulator.append(byte)

						guard
							UnicodeScalar(byte) == "\n".unicodeScalars.first
						else { continue }

						defer { accumulator = Data() }
						guard
							let string = String(data: accumulator, encoding: .utf8)
						else {
							continuation.yield("Error: Non string data. Perhaps you wanted data or bytes output?")
							continue
						}
						continuation.yield(string)
					}
					continuation.finish()
				}
			}
			readLinesStream = new
			return new
		}
	}
}

// MARK: Transmitting
extension SerialPort {

    public func writeBytes(from buffer: UnsafeMutablePointer<UInt8>, size: Int) throws -> Int {
        lock.lock()
        defer { lock.unlock() }
        guard let fileDescriptor = fileDescriptor else {
            throw PortError.mustBeOpen
        }
        var writefds = fd_set()
        var totalBytesWritten = size_t()

        while totalBytesWritten < size {
            // Initialize the fd_set to an empty set
            writefds.zero()
            // Add fd_ to the writefds set
            writefds.set(fileDescriptor)

            // Wait for the file descriptor to become ready to write
            var timeout = timespec(tv_sec: time_t(timeout * 10), tv_nsec: 0)
            let r = pselect(fileDescriptor + 1, nil, &writefds, nil, &timeout, nil);

            guard r > 0 else {
                if r == 0 {
                    throw PortError.timeout
                }
                let code = errno
                // Select was interrupted, try again
                if (code == EINTR) {
                    continue;
                }
                // Otherwise there was some error
                throw PortError(rawValue: code)
            }

            // Make sure our file descriptor is in the ready to write list
            guard writefds.isSet(fileDescriptor) else {
                assertionFailure("select reports ready to write, but our fd isn't in the list, this shouldn't happen!")
                throw PortError.internalInconsistency
            }

            let bytesWritten = write(fileDescriptor, buffer + totalBytesWritten, size - totalBytesWritten)
            guard bytesWritten >= 0 else { throw PortError(rawValue: errno) }

            totalBytesWritten += bytesWritten;
            assert(totalBytesWritten <= size, "write over wrote")
        }
        return totalBytesWritten;
    }

	public func writeData(_ data: Data) throws -> Int {
		let size = data.count
		let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: size)
		defer {
			buffer.deallocate()
		}

		data.copyBytes(to: buffer, count: size)

		let bytesWritten = try writeBytes(from: buffer, size: size)
		return bytesWritten
	}

    public func writeString(_ string: String, encoding: String.Encoding = .utf8) throws -> Int {
        guard let data = string.data(using: encoding) else {
            throw CocoaError(.fileWriteInapplicableStringEncoding, userInfo: [NSStringEncodingErrorKey: encoding.rawValue])
		}

		return try writeData(data)
	}

	public func writeChar(_ character: UnicodeScalar) throws -> Int{
		let stringEquiv = String(character)
		let bytesWritten = try writeString(stringEquiv)
		return bytesWritten
	}
}

extension fd_set {

    /**
     Replacement for FD_ZERO macro.

     - Parameter set: A pointer to a fd_set structure.

     - Returns: The set that is opinted at is filled with all zero's.
     */

    mutating func zero() {
        fds_bits = (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
    }

    /**
     Replacement for FD_SET macro

     - Parameter fd: A file descriptor that offsets the bit to be set to 1 in the fd_set pointed at by 'set'.
     - Parameter set: A pointer to a fd_set structure.

     - Returns: The given set is updated in place, with the bit at offset 'fd' set to 1.

     - Note: If you receive an EXC_BAD_INSTRUCTION at the mask statement, then most likely the socket was already closed.
     */

    mutating func set(_ fd: Int32) {
        let intOffset = Int(fd / 32)
        let bitOffset = fd % 32
        let mask: Int32 = 1 << bitOffset
        switch intOffset {
        case 0: fds_bits.0 = fds_bits.0 | mask
        case 1: fds_bits.1 = fds_bits.1 | mask
        case 2: fds_bits.2 = fds_bits.2 | mask
        case 3: fds_bits.3 = fds_bits.3 | mask
        case 4: fds_bits.4 = fds_bits.4 | mask
        case 5: fds_bits.5 = fds_bits.5 | mask
        case 6: fds_bits.6 = fds_bits.6 | mask
        case 7: fds_bits.7 = fds_bits.7 | mask
        case 8: fds_bits.8 = fds_bits.8 | mask
        case 9: fds_bits.9 = fds_bits.9 | mask
        case 10: fds_bits.10 = fds_bits.10 | mask
        case 11: fds_bits.11 = fds_bits.11 | mask
        case 12: fds_bits.12 = fds_bits.12 | mask
        case 13: fds_bits.13 = fds_bits.13 | mask
        case 14: fds_bits.14 = fds_bits.14 | mask
        case 15: fds_bits.15 = fds_bits.15 | mask
        case 16: fds_bits.16 = fds_bits.16 | mask
        case 17: fds_bits.17 = fds_bits.17 | mask
        case 18: fds_bits.18 = fds_bits.18 | mask
        case 19: fds_bits.19 = fds_bits.19 | mask
        case 20: fds_bits.20 = fds_bits.20 | mask
        case 21: fds_bits.21 = fds_bits.21 | mask
        case 22: fds_bits.22 = fds_bits.22 | mask
        case 23: fds_bits.23 = fds_bits.23 | mask
        case 24: fds_bits.24 = fds_bits.24 | mask
        case 25: fds_bits.25 = fds_bits.25 | mask
        case 26: fds_bits.26 = fds_bits.26 | mask
        case 27: fds_bits.27 = fds_bits.27 | mask
        case 28: fds_bits.28 = fds_bits.28 | mask
        case 29: fds_bits.29 = fds_bits.29 | mask
        case 30: fds_bits.30 = fds_bits.30 | mask
        case 31: fds_bits.31 = fds_bits.31 | mask
        default: break
        }
    }

    /**
     Replacement for FD_ISSET macro

     - Parameter fd: A file descriptor that offsets the bit to be tested in the fd_set pointed at by 'set'.
     - Parameter set: A pointer to a fd_set structure.

     - Returns: 'true' if the bit at offset 'fd' is 1, 'false' otherwise.
     */

    func isSet(_ fd: Int32) -> Bool {
        let intOffset = Int(fd / 32)
        let bitOffset = fd % 32
        let mask: Int32 = 1 << bitOffset
        switch intOffset {
        case 0: return fds_bits.0 & mask != 0
        case 1: return fds_bits.1 & mask != 0
        case 2: return fds_bits.2 & mask != 0
        case 3: return fds_bits.3 & mask != 0
        case 4: return fds_bits.4 & mask != 0
        case 5: return fds_bits.5 & mask != 0
        case 6: return fds_bits.6 & mask != 0
        case 7: return fds_bits.7 & mask != 0
        case 8: return fds_bits.8 & mask != 0
        case 9: return fds_bits.9 & mask != 0
        case 10: return fds_bits.10 & mask != 0
        case 11: return fds_bits.11 & mask != 0
        case 12: return fds_bits.12 & mask != 0
        case 13: return fds_bits.13 & mask != 0
        case 14: return fds_bits.14 & mask != 0
        case 15: return fds_bits.15 & mask != 0
        case 16: return fds_bits.16 & mask != 0
        case 17: return fds_bits.17 & mask != 0
        case 18: return fds_bits.18 & mask != 0
        case 19: return fds_bits.19 & mask != 0
        case 20: return fds_bits.20 & mask != 0
        case 21: return fds_bits.21 & mask != 0
        case 22: return fds_bits.22 & mask != 0
        case 23: return fds_bits.23 & mask != 0
        case 24: return fds_bits.24 & mask != 0
        case 25: return fds_bits.25 & mask != 0
        case 26: return fds_bits.26 & mask != 0
        case 27: return fds_bits.27 & mask != 0
        case 28: return fds_bits.28 & mask != 0
        case 29: return fds_bits.29 & mask != 0
        case 30: return fds_bits.30 & mask != 0
        case 31: return fds_bits.31 & mask != 0
        default: return false
        }
    }

}
