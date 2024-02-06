#if canImport(Darwin)
import Darwin
#endif
import Foundation

public struct PortMode: RawRepresentable, OptionSet {

    public let rawValue: Int32

    /// Can be initialized
    public init(rawValue: Int32) {
        self.rawValue = rawValue
    }

    /// open for reading only
    public static let readOnly = PortMode(rawValue: O_RDONLY)
    /// open for writing only
    public static let writeOnly = PortMode(rawValue: O_WRONLY)
    /// open for reading and writing
    public static let readWrite = PortMode(rawValue: O_RDWR)
    /// don't assign controlling terminal
    public static let noControllingTerminal = PortMode(rawValue: O_NOCTTY)

    /// no delay
    public static let nonBlocking = PortMode(rawValue: O_NONBLOCK)
    /// set append mode
    public static let append = PortMode(rawValue: O_APPEND)

    /// open with shared file lock
    public static let sharedLock = PortMode(rawValue: O_SHLOCK)
    /// open with exclusive file lock
    public static let exclusiveLock = PortMode(rawValue: O_EXLOCK)
    /// signal pgrp when data ready
    public static let async = PortMode(rawValue: O_ASYNC)
    /// synch I/O file integrity
    public static let sync = PortMode(rawValue: O_SYNC)

    /// implicitly set FD_CLOEXEC (close-on-exec flag)
    public static let closeOnExec = PortMode(rawValue: O_CLOEXEC)

    // default OS-specific configurations
#if os(Linux)
    public static let receive = PortMode(rawValue: O_RDONLY | O_NOCTTY)
    public static let transmit = PortMode(rawValue: O_WRONLY | O_NOCTTY)
    public static let receiveAndTransmit = PortMode(rawValue: O_RDWR | O_NOCTTY)
#elseif os(OSX)
    public static let receive = PortMode(rawValue: O_RDONLY | O_NOCTTY | O_EXLOCK)
    public static let transmit = PortMode(rawValue: O_WRONLY | O_NOCTTY | O_EXLOCK)
    public static let receiveAndTransmit = PortMode(rawValue: O_RDWR | O_NOCTTY | O_EXLOCK)
#endif

}
