import Foundation
import Observation

/// One selectable value of a knob.
struct KnobOption: Hashable, Sendable {
    let value: String
    let label: String

    init(_ value: String, _ label: String) {
        self.value = value
        self.label = label
    }
}

/// A named control on a lab: its options, default, and what Apple says about it.
struct KnobSpec: Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let options: [KnobOption]
    let defaultValue: String
    /// "Apple says … / watch for …" in one or two sentences.
    let note: String
    /// Fact IDs from `research/` (F-, T-, M-) and decision IDs (D-).
    let facts: [String]

    init(_ id: String, _ title: String, options: [KnobOption], default defaultValue: String? = nil,
         note: String, facts: [String] = []) {
        precondition(!options.isEmpty, "knob \(id) needs options")
        self.id = id
        self.title = title
        self.options = options
        self.defaultValue = defaultValue ?? options[0].value
        self.note = note
        self.facts = facts
    }

    static func toggle(_ id: String, _ title: String, default on: Bool = false,
                       note: String, facts: [String] = []) -> KnobSpec {
        KnobSpec(id, title, options: [KnobOption("off", "Off"), KnobOption("on", "On")],
                 default: on ? "on" : "off", note: note, facts: facts)
    }

    func isValid(_ value: String) -> Bool { options.contains { $0.value == value } }

    func label(for value: String) -> String {
        options.first { $0.value == value }?.label ?? value
    }
}

/// Live knob values for one lab. Only values listed in the lab's specs are accepted.
@Observable
final class KnobState {
    let lab: LabID
    private(set) var values: [String: String]

    init(lab: LabID, values: [String: String] = [:]) {
        self.lab = lab
        self.values = Dictionary(uniqueKeysWithValues: lab.knobs.map { ($0.id, $0.defaultValue) })
        apply(values)
    }

    var specs: [KnobSpec] { lab.knobs }

    func spec(_ id: String) -> KnobSpec? { specs.first { $0.id == id } }

    subscript(id: String) -> String {
        get { values[id] ?? spec(id)?.defaultValue ?? "" }
        set {
            guard let spec = spec(id), spec.isValid(newValue) else { return }
            values[id] = newValue
        }
    }

    func isOn(_ id: String) -> Bool { self[id] == "on" }

    /// Applies knob values and returns a description of every rejected pair.
    @discardableResult
    func apply(_ pairs: [String: String]) -> [String] {
        var rejected: [String] = []
        for (key, value) in pairs.sorted(by: { $0.key < $1.key }) {
            guard let spec = spec(key) else {
                rejected.append("\(lab.rawValue) has no knob '\(key)'")
                continue
            }
            guard spec.isValid(value) else {
                let allowed = spec.options.map(\.value).joined(separator: ", ")
                rejected.append("\(key)=\(value) is not one of \(allowed)")
                continue
            }
            values[key] = value
        }
        return rejected
    }

    func reset() {
        for spec in specs { values[spec.id] = spec.defaultValue }
    }

    var isDefault: Bool { specs.allSatisfy { self[$0.id] == $0.defaultValue } }

    /// Stable identifier for the current variant, e.g. `grids:layout=adaptive,edge=fade`.
    var variantKey: String {
        lab.rawValue + ":" + specs.map { "\($0.id)=\(self[$0.id])" }.joined(separator: ",")
    }

    /// Human-readable variant, e.g. `Layout: Adaptive · Edge: Fade`.
    var summary: String {
        specs.map { "\($0.title): \($0.label(for: self[$0.id]))" }.joined(separator: " · ")
    }

    /// The deep link that reproduces this variant.
    var deepLink: String {
        let query = specs.map { "\($0.id)=\(self[$0.id])" }.joined(separator: "&")
        return "duolab://lab/\(lab.rawValue)?\(query)&open=1"
    }

    func copy() -> KnobState { KnobState(lab: lab, values: values) }

    /// Inverse of `variantKey`.
    static func parse(variantKey: String) -> (lab: LabID, values: [String: String])? {
        let parts = variantKey.split(separator: ":", maxSplits: 1).map(String.init)
        guard parts.count == 2, let lab = LabID(rawValue: parts[0]) else { return nil }
        var values: [String: String] = [:]
        for pair in parts[1].split(separator: ",") {
            let kv = pair.split(separator: "=", maxSplits: 1).map(String.init)
            guard kv.count == 2 else { return nil }
            values[kv[0]] = kv[1]
        }
        return (lab, values)
    }
}
