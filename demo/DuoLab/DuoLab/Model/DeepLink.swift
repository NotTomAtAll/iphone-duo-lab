import Foundation

/// A navigation request from a URL (`duolab://…`) or from launch arguments.
///
/// URL forms:
/// - `duolab://topic/<lab>` opens a topic page.
/// - `duolab://topic/<lab>/<option>?<knob>=<value>&measure=1` previews an option.
/// - `duolab://tab/<topics|playbook|device>`
/// - `duolab://tour` starts the guided tour; `duolab://tour/<step>?paused=1&compare=1`.
///
/// Launch arguments: `-topic <lab> -option <id> -knob.<name> <value> -measure 1 -tab <name>`,
/// and `-tour 1 -tourStep <n> -tourPaused 1 -tourCompare 1` for the tour.
struct DeepLink: Equatable {
    var tab: RootTab?
    var lab: LabID?
    var option: String?
    var knobs: [String: String] = [:]
    var measure: Bool?
    var tour: TourLaunch?
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
        case "tour":
            var tour = TourLaunch()
            if let target = parts.first {
                if let step = parseStep(target) { tour.step = step } else { link.errors.append("Tour step “\(target)” is not a number from 1") }
            }
            link.tour = tour
        default:
            link.errors.append("Unknown link \(url.absoluteString)")
        }

        for item in components.queryItems ?? [] {
            let value = item.value ?? ""
            if link.tour != nil, ["step", "paused", "compare"].contains(item.name) {
                switch item.name {
                case "step":
                    if let step = parseStep(value) { link.tour?.step = step } else { link.errors.append("Tour step “\(value)” is not a number from 1") }
                case "paused": link.tour?.paused = parseBool(value) ?? false
                default: link.tour?.compare = parseBool(value) ?? false
                }
            } else if item.name == "measure" {
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
        var tour: TourLaunch?
        var tourStep: Int?
        var tourPaused = false
        var tourCompare = false
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
            case "-tour":
                if parseBool(value) == true {
                    found = true
                    tour = TourLaunch()
                }
            case "-tourStep":
                if let step = parseStep(value) { tourStep = step } else { link.errors.append("Tour step “\(value)” is not a number from 1") }
            case "-tourPaused":
                tourPaused = parseBool(value) ?? false
            case "-tourCompare":
                tourCompare = parseBool(value) ?? false
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
        if var tour {
            tour.step = tourStep ?? 1
            tour.paused = tourPaused
            tour.compare = tourCompare
            link.tour = tour
        }
        return found ? link : nil
    }

    private static func parseStep(_ value: String) -> Int? {
        guard let step = Int(value), step >= 1 else { return nil }
        return step
    }

    private static func parseBool(_ value: String) -> Bool? {
        switch value.lowercased() {
        case "1", "true", "yes", "on": true
        case "0", "false", "no", "off": false
        default: nil
        }
    }
}
