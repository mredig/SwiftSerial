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
