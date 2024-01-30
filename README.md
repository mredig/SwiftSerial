# Swift Serial

This project began its life as yeokm1's [SwiftSerial](https://github.com/yeokm1/SwiftSerial). He has since archived the project and was kind enough to link this project going forward.

### Getting started

```swift

import SwiftSerial

...

// setup
let serialPort = SerialPort(path: "/dev/cu.usbmodem1234") // you'll need to find the correct device on your own, but this is what it will resemble on a mac
try serialPort.openPort()

serialPort.setSettings(
	receiveRate: 115200,
	transmitRate: 115200,
	minimumBytesToRead: 1)


// read output
Task {
	let readStream = try serialPort.asyncLines()

	for await line in readStream {
		print(line, terminator: "")
	}
}

// send data
try serialPort.writeString("foo")
// or
try serialPort.writeData(Data([1,2,3,4]))
```

### SPM Import
```swift
.package(url: "https://github.com/mredig/SwiftSerial", .upToNextMinor("1.0.0")
```

### What's New?
* Modernized and Swiftier syntax
* TABS!
	* Modular indentation style, allowing for anyone to read the code however it reads best to them
* Broke separate symbols into their own files
* Monitoring output and delivering via AsyncStream for reading instead of the old polling, or dare I say, omniscience, 
method, where you need to know exactly how many bytes or lines to read.
* Thread safety
* BaudRate has UInt initializer
* Added `SwiftTerminal` demo to connect and interface with a serial connection
