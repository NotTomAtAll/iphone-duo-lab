import Foundation

/// A navigation request from a URL (`duolab://…`) or from launch arguments.
///
/// URL forms:
/// - `duolab://topic/<lab>` opens a topic page.
/// - `duolab://topic/<lab>/<option>?<knob>=<value>&measure=1` previews an option.
/// - `duolab://tab/<topics|playbook|device>`
///
/// Launch arguments: `-topic <lab> -option <id> -knob.<name> <value> -measure 1 -tab <name>`.
struct DeepLink: Equatable {
    var tab: RootTab?
    var lab: LabID?
    var option: String?
    var knobs: [String: String] = [:]
    var measure: Bool?
    /// Problems found while parsing. Shown to the user, never fatal.
    var errors: [String] = []

    static let scheme = "duolab"

    static func parse(url: URL) -> DeepLink? {
        guard url.scheme?.lowercased() == scheme,
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return nil }
        var link = DeepLink()
        let parts = url.pathComponents.filter { $0 != "/" }

        switch components.host?.lowercased() {
        case "topic":
            link.tab = .topics
            let target = parts.first ?? ""
            if let lab = LabID(rawValue: target.lowercased()) {
                link.lab = lab
                if parts.count > 1 { link.option = parts[1].lowercased() }
            } else {
                link.errors.append("Unknown topic “\(target)”")
            }
        case "tab":
            let target = parts.first ?? ""
            if let tab = RootTab(rawValue: target.lowercased()) {
                link.tab = tab
            } else {
                link.errors.append("Unknown tab “\(target)”")
            }
        default:
            link.errors.append("Unknown link \(url.absoluteString)")
        }

        for item in components.queryItems ?? [] {
            let value = item.value ?? ""
            if item.name == "measure" {
                link.measure = parseBool(value)
            } else {
                link.knobs[item.name] = value
            }
        }
        return link
    }

    static func parse(arguments: [String]) -> DeepLink? {
        var link = DeepLink()
        var found = false
        var index = 0
        while index < arguments.count {
            let key = arguments[index]
            let value = index + 1 < arguments.count ? arguments[index + 1] : ""
            var consumed = true
            switch key {
            case "-topic":
                found = true
                link.tab = .topics
                if let lab = LabID(rawValue: value.lowercased()) {
                    link.lab = lab
                } else {
                    link.errors.append("Unknown topic “\(value)”")
                }
            case "-option":
                found = true
                link.option = value.lowercased()
            case "-tab":
                found = true
                if let tab = RootTab(rawValue: value.lowercased()) {
                    link.tab = tab
                } else {
                    link.errors.append("Unknown tab “\(value)”")
                }
            case "-measure":
                found = true
                link.measure = parseBool(value)
            default:
                if key.hasPrefix("-knob.") {
                    found = true
                    link.knobs[String(key.dropFirst("-knob.".count))] = value
                } else {
                    consumed = false
                }
            }
            index += consumed ? 2 : 1
        }
        return found ? link : nil
    }

    private static func parseBool(_ value: String) -> Bool? {
        switch value.lowercased() {
        case "1", "true", "yes", "on": true
        case "0", "false", "no", "off": false
        default: nil
        }
    }
}
