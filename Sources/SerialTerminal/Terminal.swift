import Foundation
import SwiftSerial
import ArgumentParser

private var readTask: Task<Void, Error>?

@main
struct Terminal: AsyncParsableCommand {
	@Argument(help: "Path to port (aka /dev/cu.serialsomethingorother)")
	var path: String

	@Argument(help: "Baud Rate", transform: {
		let value = UInt($0) ?? 1
		return try BaudRate(value)
	})
	var baudRate: BaudRate

	private var writeBuffer: String = ""

	func run() async throws {
		let serialPort = SerialPort(path: path)
		try serialPort.openPort()
		try serialPort.setSettings(receiveRate: baudRate, transmitRate: baudRate, minimumBytesToRead: 1)

		readTask = Task {
			let lines = try serialPort.asyncLines()

			for await line in lines {
				print(line, terminator: "")
			}
		}

		while let line = readLine(strippingNewline: false) {
			_ = try serialPort.writeString(line)
		}
	}
}
