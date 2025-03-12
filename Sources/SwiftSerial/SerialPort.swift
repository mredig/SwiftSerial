import Foundation

/// SerialPort acts as the handle to manipulate and read the serial input and output.
public class SerialPort {
	
	/// Path to the system device the serial port resides at. For example, `/dev/cu.serialsoemthingorother`
	var path: String
	/// Storage for the file descriptor of the path. Probably don't edit this. (I should probably make private, but I don't know if there's anything relying on it)
	var fileDescriptor: Int32?

	private var isOpen: Bool { fileDescriptor != nil }

	private var pollSource: DispatchSourceRead?
	private var readDataStream: AsyncStream<Data>?
	private var readBytesStream: AsyncStream<UInt8>?
	private var readLinesStream: AsyncStream<String>?

	private let lock = NSLock()
	
	/// Create a new `SerialPort` object
	/// - Parameter path: Path to the system device the serial port resides at. For example, `/dev/cu.serialsoemthingorother`
	public init(path: String) {
		self.path = path
	}

	/// Opens and establishes the connection with the serial port.
	public func openPort(portMode: PortMode = .receiveAndTransmit) throws(PortError) {
		lock.lock()
		defer { lock.unlock() }
		guard !path.isEmpty else { throw PortError.invalidPath }
		guard isOpen == false else { throw PortError.instanceAlreadyOpen }

		let readWriteParam: Int32

		switch portMode {
		case .receive:
			readWriteParam = O_RDONLY
		case .transmit:
			readWriteParam = O_WRONLY
		case .receiveAndTransmit:
			readWriteParam = O_RDWR
		}

		#if os(Linux)
		fileDescriptor = open(path, readWriteParam | O_NOCTTY)
		#elseif os(OSX)
		fileDescriptor = open(path, readWriteParam | O_NOCTTY | O_EXLOCK)
		#endif

		// Throw error if open() failed
		if fileDescriptor == PortError.failedToOpen.rawValue {
			throw PortError.failedToOpen
		}

		guard
			portMode.receive,
			let fileDescriptor
		else { return }
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
	
	/// Value for the BaudRate of a connection
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
	
	/// Sets the settings of a serial port connection.
	///
	/// Many of these values should be referenced from the underlying C calls and structs:
	///	* `tcsetattr`
	/// * `termios`
	/// * `cfsetispeed`
	/// * `cfsetospeed`
	/// * `cc_t`
	/// * `tcflag_t`
	///
	/// - Parameters:
	///   - baudRateSetting: Speed/baud rate of the connection
	///   - minimumBytesToRead: The minimum bytes to read
	///   - timeout: `0` means indefinite.
	///   - parityType: parity type
	///   - sendTwoStopBits: defaults to false. `1` stop bit is used on false
	///   - dataBitsSize: defaults to `.bits8`
	///   - useHardwareFlowControl: defaults to `false`
	///   - useSoftwareFlowControl: defaults to `false`
	///   - processOutput: defaults to `false`
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
		tcgetattr(fileDescriptor, &settings)

		// Set baud rates
		cfsetispeed(&settings, baudRateSetting.receiveRate.speedValue)
		cfsetospeed(&settings, baudRateSetting.transmitRate.speedValue)

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
	
	/// Closes the port
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
	/// Retrieves the `AsyncStream<Data>`. Don't run this more than once as streams can only produce output for a single subscriber.
	public func asyncData() throws(PortError) -> AsyncStream<Data> {
		guard
			isOpen,
			let readDataStream
		else {
			throw PortError.mustBeOpen
		}

		return readDataStream
	}

	/// Retrieves the `AsyncStream<UInt8>`. Don't run this more than once as streams can only produce output for a single subscriber.
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

	/// Retrieves the `AsyncStream<String>`. Don't run this more than once as streams can only produce output for a single subscriber.
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
	/// Writes to the `SerialPort`. You can also think of this as sending data.
	/// - Parameters:
	///   - buffer: pointer to the raw memory being sent
	///   - size: how many bytes to read from `buffer`
	/// - Returns: Count of bytes written
	public func writeBytes(from buffer: UnsafeMutablePointer<UInt8>, size: Int) throws -> Int {
		lock.lock()
		defer { lock.unlock() }
		guard let fileDescriptor = fileDescriptor else {
			throw PortError.mustBeOpen
		}

		let bytesWritten = write(fileDescriptor, buffer, size)
		return bytesWritten
	}
	
	/// Writes to the `SerialPort`. You can also think of this as sending data.
	/// - Parameter data: The chunk of data you want to send.
	/// - Returns: Count of bytes written
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
	
	/// Writes to the `SerialPort`. You can also think of this as sending data.
	/// - Parameter string: String of characters you wish to send.
	/// - Returns: Count of bytes written.
	public func writeString(_ string: String) throws -> Int {
		guard let data = string.data(using: String.Encoding.utf8) else {
			throw PortError.stringsMustBeUTF8
		}

		return try writeData(data)
	}
	
	/// Writes to the `SerialPort`. You can also think of this as sending data.
	/// - Parameter character: The single `UnicodeScalar` to write to the buffer.
	/// - Returns: Count of byte(s) written.
	public func writeChar(_ character: UnicodeScalar) throws -> Int{
		let stringEquiv = String(character)
		let bytesWritten = try writeString(stringEquiv)
		return bytesWritten
	}
}
