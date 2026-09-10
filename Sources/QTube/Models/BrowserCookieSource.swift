import Foundation

enum BrowserCookieSource: String, CaseIterable, Identifiable {
    case auto
    case none
    case chrome
    case firefox
    case safari

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .auto: return "Tự động tối ưu"
        case .none: return "Không dùng cookie"
        case .chrome: return "Google Chrome"
        case .firefox: return "Firefox"
        case .safari: return "Safari"
        }
    }

    var ytDLPIdentifier: String? {
        switch self {
        case .auto, .none: return nil
        case .chrome, .firefox, .safari: return rawValue
        }
    }

    static var browsers: [BrowserCookieSource] {
        allCases.filter { $0 != .auto && $0 != .none }
    }
}
