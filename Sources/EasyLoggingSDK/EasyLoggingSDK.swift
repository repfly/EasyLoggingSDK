@_exported import EasyLoggingCore
@_exported import EasyLoggingNetwork
#if canImport(UIKit)
@_exported import EasyLoggingUI
#endif

public enum EasyLoggingSDK {
    /// Wires up the network and UIKit/SwiftUI feature layers with `EasyLogger.shared`.
    /// Call once at launch; repeated calls are no-ops.
    @MainActor
    public static func activate() {
        EasyLoggingNetwork.install()
        #if canImport(UIKit)
        EasyLoggingUI.install()
        #endif
    }
}
