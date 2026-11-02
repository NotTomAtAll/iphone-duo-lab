import Foundation
import Observation

/// The option a team chose for one topic.
struct Decision: Codable, Equatable, Sendable {
    var lab: LabID
    var optionID: String
    /// Knob values changed in Fine-tune on top of the option's preset.
    var tweaks: [String: String] = [:]
    var rationale: String = ""
    var date: Date
}

/// One decision per topic, persisted as JSON in UserDefaults. Exports as a markdown playbook.
@Observable
final class DecisionStore {
    private(set) var decisions: [Decision]
    private let defaults: UserDefaults
    private let key: String

    init(defaults: UserDefaults = .standard, key: String = "duolab.decisions") {
        self.defaults = defaults
        self.key = key
        self.decisions = Self.decode(defaults.data(forKey: key))
    }

    func decision(for lab: LabID) -> Decision? { decisions.first { $0.lab == lab } }

    func chosenOption(for lab: LabID) -> LabOption? {
        decision(for: lab).flatMap { lab.option($0.optionID) }
    }

    func isChosen(_ option: LabOption, in lab: LabID) -> Bool {
        decision(for: lab)?.optionID == option.id
    }

    var decidedCount: Int { LabID.allCases.filter { decision(for: $0) != nil }.count }

    /// Records `option` for `lab`. Pass the live state to keep Fine-tune changes.
    func choose(_ option: LabOption, in lab: LabID, state: KnobState? = nil, now: Date = .now) {
        let rationale = decision(for: lab)?.rationale ?? ""
        var tweaks: [String: String] = [:]
        if let state {
            let preset = KnobState(lab: lab, values: option.knobs)
            for spec in lab.knobs where state[spec.id] != preset[spec.id] {
                tweaks[spec.id] = state[spec.id]
            }
        }
        decisions.removeAll { $0.lab == lab }
        decisions.append(Decision(lab: lab, optionID: option.id, tweaks: tweaks, rationale: rationale, date: now))
        save()
    }

    func clear(_ lab: LabID) {
        decisions.removeAll { $0.lab == lab }
        save()
    }

    func clearAll() {
        decisions.removeAll()
        save()
    }

    func setRationale(_ text: String, for lab: LabID) {
        guard let index = decisions.firstIndex(where: { $0.lab == lab }) else { return }
        decisions[index].rationale = text
        save()
    }

    func markdown(now: Date = .now) -> String { Self.markdown(for: decisions, now: now) }

    static func markdown(for decisions: [Decision], now: Date) -> String {
        let decided = LabID.allCases.filter { lab in decisions.contains { $0.lab == lab } }.count
        let day = now.formatted(.iso8601.year().month().day())
        var lines = [
            "# iPhone Duo playbook",
            "",
            "\(decided) of \(LabID.allCases.count) topics decided · \(day)",
            "",
        ]
        for lab in LabID.allCases {
            lines.append("## \(lab.numberText) \(lab.title)")
            lines.append("")
            lines.append("> \(lab.question)")
            lines.append("")
            if let decision = decisions.first(where: { $0.lab == lab }), let option = lab.option(decision.optionID) {
                lines.append("**\(option.title)** (\(option.verdict.title)). \(option.summary)")
                let why = decision.rationale.trimmingCharacters(in: .whitespacesAndNewlines)
                if !why.isEmpty { lines += ["", "Why: \(why)"] }
                if !decision.tweaks.isEmpty {
                    let tweaks = decision.tweaks.sorted { $0.key < $1.key }.map { "\($0.key)=\($0.value)" }.joined(separator: ", ")
                    lines += ["", "Adjusted: \(tweaks)"]
                }
                var link = "duolab://topic/\(lab.rawValue)/\(option.id)"
                if !decision.tweaks.isEmpty {
                    link += "?" + decision.tweaks.sorted { $0.key < $1.key }.map { "\($0.key)=\($0.value)" }.joined(separator: "&")
                }
                lines += ["", "Try it: `\(link)`"]
            } else {
                lines.append("_Not decided yet._")
            }
            lines.append("")
        }
        return lines.joined(separator: "\n")
    }

    static func encode(_ decisions: [Decision]) -> Data? { try? JSONEncoder().encode(decisions) }

    static func decode(_ data: Data?) -> [Decision] {
        guard let data else { return [] }
        return (try? JSONDecoder().decode([Decision].self, from: data)) ?? []
    }

    private func save() {
        defaults.set(Self.encode(decisions), forKey: key)
    }
}
