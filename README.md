# Swift Serial

[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fmredig%2FSwiftSerial%2Fbadge%3Ftype%3Dswift-versions)](https://swiftpackageindex.com/mredig/SwiftSerial) [![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fmredig%2FSwiftSerial%2Fbadge%3Ftype%3Dplatforms)](https://swiftpackageindex.com/mredig/SwiftSerial)

This project began its life as yeokm1's [SwiftSerial](https://github.com/yeokm1/SwiftSerial). He has since archived the project and was kind enough to link this fork going forward.

### Getting started

```swift

import SwiftSerial

...

// setup
let serialPort = SerialPort(path: "/dev/cu.usbmodem1234") // you'll need to find the correct device on your own, but this is what it will resemble on a mac
try serialPort.openPort()

try serialPort.setSettings(
	baudRateSetting: .symmetrical(.baud115200),
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

See the demo CLI app `SwiftTerminal` for a working example.

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
* I kept the original methods that I changed around, but marked as deprecated. I intend to eventually remove them, but I don't want to disrupt anyone relying on this in the meantime.
