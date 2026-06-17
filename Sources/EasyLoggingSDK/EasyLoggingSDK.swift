@_exported import EasyLoggingCore
@_exported import EasyLoggingNetwork
#if canImport(UIKit)
@_exported import EasyLoggingUI
#endif

public enum EasyLoggingSDK {
    /// Wires up the UIKit/SwiftUI integrations with ``EasyLogger/shared``. Call once at launch.
    @MainActor
    public static func activate() {
        #if canImport(UIKit)
        EasyLoggingUI.install()
        #endif
    }
}
