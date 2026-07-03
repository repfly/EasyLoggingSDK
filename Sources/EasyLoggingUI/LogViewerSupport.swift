#if canImport(UIKit)
import EasyLoggingCore
import SwiftUI
import UIKit

let allLogLevels: [LogLevel] = [.trace, .debug, .info, .warning, .error, .critical]

func color(for level: LogLevel) -> Color {
    switch level {
    case .trace: return .gray
    case .debug: return Color(.systemGray)
    case .info: return .blue
    case .warning: return .orange
    case .error: return .red
    case .critical: return .purple
    }
}

func color(forStatusCode statusCode: Int?, isFailure: Bool) -> Color {
    guard let statusCode else { return isFailure ? .red : .gray }
    switch statusCode {
    case 200..<300: return .green
    case 300..<400: return .blue
    case 400..<500: return .orange
    default: return .red
    }
}

func color(forMethod method: String) -> Color {
    switch method.uppercased() {
    case "GET": return .blue
    case "POST": return .green
    case "PUT", "PATCH": return .orange
    case "DELETE": return .red
    default: return .gray
    }
}

struct ActivityView: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
#endif
