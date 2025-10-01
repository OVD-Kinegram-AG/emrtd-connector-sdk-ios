import Foundation
import CoreNFC

/// Simple NFC availability checker
public struct NFCCapabilityChecker {

    /// Check if the device supports passport reading
    public static var isAvailable: Bool {
        #if targetEnvironment(simulator)
        return false
        #else
        return NFCTagReaderSession.readingAvailable
        #endif
    }

    /// Get a user-friendly error message if NFC is not available
    public static var unavailabilityReason: String? {
        #if targetEnvironment(simulator)
        return "NFC is not available on the iOS Simulator"
        #else
        if !NFCTagReaderSession.readingAvailable {
            return "This device does not support NFC"
        }
        return nil
        #endif
    }
}
