import Foundation

extension SerialPort {
	@available(*, deprecated, message: "Use `open(portMode:)` instead")
	public func openPort(toReceive receive: Bool, andTransmit transmit: Bool) throws {
		switch (receive, transmit) {
		case (true, false):
			try openPort(portMode: .receive)
		case (false, true):
			try openPort(portMode: .transmit)
		case (true, true):
			try openPort(portMode: .receiveAndTransmit)
		case (false, false):
			throw PortError.mustReceiveOrTransmit
		}
	}


	@available(*, deprecated, message: "Use async reading methods")
	public func readBytes(into buffer: UnsafeMutablePointer<UInt8>, size: Int) throws -> Int {
		guard let fileDescriptor = fileDescriptor else {
			throw PortError.mustBeOpen
		}

		var s: stat = stat()
		fstat(fileDescriptor, &s)
		if s.st_nlink != 1 {
			throw PortError.deviceNotConnected
		}

		let bytesRead = read(fileDescriptor, buffer, size)
		return bytesRead
	}

	@available(*, deprecated, message: "Use async reading methods")
	public func readData(ofLength length: Int) throws -> Data {
		let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: length)
		defer {
			buffer.deallocate()
		}

		let bytesRead = try readBytes(into: buffer, size: length)

		var data : Data

		if bytesRead > 0 {
			data = Data(bytes: buffer, count: bytesRead)
		} else {
			//This is to avoid the case where bytesRead can be negative causing problems allocating the Data buffer
			data = Data(bytes: buffer, count: 0)
		}

		return data
	}

	@available(*, deprecated, message: "Use async reading methods")
	public func readString(ofLength length: Int) throws -> String {
		var remainingBytesToRead = length
		var result = ""

		while remainingBytesToRead > 0 {
			let data = try readData(ofLength: remainingBytesToRead)

			if let string = String(data: data, encoding: String.Encoding.utf8) {
				result += string
				remainingBytesToRead -= data.count
			} else {
				return result
			}
		}

		return result
	}

	@available(*, deprecated, message: "Use async reading methods")
	public func readUntilChar(_ terminator: CChar) throws -> String {
		var data = Data()
		let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: 1)
		defer {
			buffer.deallocate()
		}

		while true {
			let bytesRead = try readBytes(into: buffer, size: 1)

			if bytesRead > 0 {
				if ( buffer[0] > 127) {
					throw PortError.unableToConvertByteToCharacter
				}
				let character = CChar(buffer[0])

				if character == terminator {
					break
				} else {
					data.append(buffer, count: 1)
				}
			}
		}

		if let string = String(data: data, encoding: String.Encoding.utf8) {
			return string
		} else {
			throw PortError.stringsMustBeUTF8
		}
	}

	@available(*, deprecated, message: "Use async reading methods")
	public func readLine() throws -> String {
		let newlineChar = CChar(10) // Newline/Line feed character `\n` is 10
		return try readUntilChar(newlineChar)
	}

	@available(*, deprecated, message: "Use async reading methods")
	public func readByte() throws -> UInt8 {
		let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: 1)

		defer {
			buffer.deallocate()
		}

		while true {
			let bytesRead = try readBytes(into: buffer, size: 1)

			if bytesRead > 0 {
				return buffer[0]
			}
		}
	}

	@available(*, deprecated, message: "Use async reading methods")
	public func readChar() throws -> UnicodeScalar {
		let byteRead = try readByte()
		let character = UnicodeScalar(byteRead)
		return character
	}
}
