import Foundation
import Testing
@testable import DuoLab

struct DeepLinkTests {
    @Test func optionURLWithKnobsAndMeasure() throws {
        let link = try #require(DeepLink.parse(url: URL(string: "duolab://topic/grids/fixed-two?edge=fade&measure=1")!))
        #expect(link.tab == .topics)
        #expect(link.lab == .grids)
        #expect(link.option == "fixed-two")
        #expect(link.knobs == ["edge": "fade"])
        #expect(link.measure == true)
        #expect(link.errors.isEmpty)
    }

    @Test func topicURL() throws {
        let link = try #require(DeepLink.parse(url: URL(string: "duolab://topic/media")!))
        #expect(link.lab == .media)
        #expect(link.option == nil)
    }

    @Test func tabURL() throws {
        let link = try #require(DeepLink.parse(url: URL(string: "duolab://tab/playbook")!))
        #expect(link.tab == .playbook)
        #expect(link.lab == nil)
    }

    @Test func unknownTopicIsAnErrorNotACrash() throws {
        let link = try #require(DeepLink.parse(url: URL(string: "duolab://topic/nope")!))
        #expect(link.lab == nil)
        #expect(link.errors.count == 1)
    }

    @Test func otherSchemeIsIgnored() {
        #expect(DeepLink.parse(url: URL(string: "https://example.com/topic/grids")!) == nil)
    }

    @Test func launchArguments() throws {
        let args = ["/path/DuoLab", "-topic", "media", "-option", "fixed-panel", "-knob.video", "ignore",
                    "-measure", "1", "-AppleLanguages", "(en)"]
        let link = try #require(DeepLink.parse(arguments: args))
        #expect(link.lab == .media)
        #expect(link.option == "fixed-panel")
        #expect(link.knobs == ["video": "ignore"])
        #expect(link.measure == true)
    }

    @Test func noRelevantArgumentsGivesNil() {
        #expect(DeepLink.parse(arguments: ["/path/DuoLab", "-AppleLanguages", "(en)"]) == nil)
    }

    @Test func routerOpensPreviewAndReportsBadOption() {
        let router = AppRouter()
        router.handle(DeepLink(tab: .topics, lab: .grids, option: "fixed-two"))
        #expect(router.focusedTopic == .grids)
        #expect(router.preview?.optionID == "fixed-two")

        let other = AppRouter()
        other.handle(DeepLink(tab: .topics, lab: .grids, option: "nope"))
        #expect(other.preview == nil)
        #expect(other.banner != nil)
    }
}

struct CatalogTests {
    @Test func everyTopicHasValidKnobs() {
        for lab in LabID.allCases {
            #expect(!lab.knobs.isEmpty, "\(lab) has no knobs")
            let ids = lab.knobs.map(\.id)
            #expect(Set(ids).count == ids.count, "\(lab) has duplicate knob ids")
            for spec in lab.knobs {
                #expect(spec.isValid(spec.defaultValue), "\(lab).\(spec.id) default is not an option")
                #expect(!spec.note.isEmpty)
            }
        }
    }

    @Test func everyTopicHasUsableOptions() {
        let allowed = Set("abcdefghijklmnopqrstuvwxyz0123456789-")
        for lab in LabID.allCases {
            let options = lab.options
            #expect(options.count >= 3, "\(lab) needs at least 3 options")
            #expect(Set(options.map(\.id)).count == options.count, "\(lab) has duplicate option ids")
            for option in options {
                #expect(option.id.allSatisfy(allowed.contains), "\(lab)/\(option.id) id")
                #expect(!option.summary.isEmpty && !option.lookFor.isEmpty, "\(lab)/\(option.id) copy")
                let state = KnobState(lab: lab)
                #expect(state.apply(option.knobs).isEmpty, "\(lab)/\(option.id) has invalid knob values")
                if let highlight = option.highlight {
                    #expect(state.spec(highlight) != nil, "\(lab)/\(option.id) highlight")
                }
            }
            let presets = options.map { KnobState(lab: lab, values: $0.knobs).variantKey }
            #expect(Set(presets).count == presets.count, "\(lab) has two options with identical settings")
        }
    }

    @Test func designTopicsLeadWithARecommendation() {
        for lab in LabID.allCases where ![.sheets, .hinge, .antiPatterns].contains(lab) {
            #expect(lab.options.contains { $0.verdict == .recommended }, "\(lab) has no recommended option")
            // Tab bar: the custom-bar anti-pattern is covered by the Toolbars topic.
            if lab != .tabBar {
                #expect(lab.options.contains { $0.verdict == .avoid }, "\(lab) shows no option to avoid")
            }
        }
    }
}

struct KnobStateTests {
    @Test func applyRejectsUnknownKnobsAndValues() {
        let state = KnobState(lab: .grids)
        let rejected = state.apply(["layout": "carousel", "edge": "sparkle", "bogus": "1"])
        #expect(state["layout"] == "carousel")
        #expect(state["edge"] == "clip")
        #expect(rejected.count == 2)
    }

    @Test func subscriptIgnoresInvalidValues() {
        let state = KnobState(lab: .reading)
        state["width"] = "9999"
        #expect(state["width"] == "560")
        state["width"] = "600"
        #expect(state["width"] == "600")
    }

    @Test func variantKeyRoundTrips() throws {
        for lab in LabID.allCases {
            let state = KnobState(lab: lab)
            for spec in lab.knobs { state[spec.id] = spec.options.last!.value }
            let parsed = try #require(KnobState.parse(variantKey: state.variantKey))
            #expect(parsed.lab == lab)
            #expect(KnobState(lab: lab, values: parsed.values).variantKey == state.variantKey)
        }
    }
}

struct DecisionStoreTests {
    private func makeStore() -> (DecisionStore, UserDefaults) {
        let defaults = UserDefaults(suiteName: "duolab.tests.\(UUID().uuidString)")!
        return (DecisionStore(defaults: defaults, key: "d"), defaults)
    }

    @Test func oneDecisionPerTopicAndPersisted() throws {
        let (store, defaults) = makeStore()
        let first = LabID.grids.options[0], second = LabID.grids.options[1]
        store.choose(first, in: .grids)
        store.choose(second, in: .grids)
        #expect(store.decisions.count == 1)
        #expect(store.isChosen(second, in: .grids))
        #expect(DecisionStore(defaults: defaults, key: "d").chosenOption(for: .grids) == second)
        store.clear(.grids)
        #expect(DecisionStore(defaults: defaults, key: "d").decisions.isEmpty)
    }

    @Test func rationaleSurvivesRechoosing() {
        let (store, _) = makeStore()
        store.choose(LabID.media.options[0], in: .media)
        store.setRationale("Live chat beside video", for: .media)
        store.choose(LabID.media.options[1], in: .media)
        #expect(store.decision(for: .media)?.rationale == "Live chat beside video")
    }

    @Test func tweaksAreOnlyTheDifferencesFromThePreset() {
        let (store, _) = makeStore()
        let option = try! #require(LabID.grids.option("adaptive-even"))
        let state = KnobState(lab: .grids, values: option.knobs)
        state["edge"] = "fade"
        store.choose(option, in: .grids, state: state)
        #expect(store.decision(for: .grids)?.tweaks == ["edge": "fade"])
    }

    @Test func codecRoundTripAndGarbage() {
        let decisions = [Decision(lab: .hinge, optionID: "lamp", rationale: "r", date: Date(timeIntervalSince1970: 1_000))]
        #expect(DecisionStore.decode(DecisionStore.encode(decisions)) == decisions)
        #expect(DecisionStore.decode(Data("garbage".utf8)).isEmpty)
        #expect(DecisionStore.decode(nil).isEmpty)
    }

    @Test func markdownPlaybook() {
        let date = Date(timeIntervalSince1970: 1_800_000_000)
        let decisions = [Decision(lab: .tabBar, optionID: "native", tweaks: ["minimize": "never"],
                                  rationale: "  Matches the system  ", date: date)]
        let markdown = DecisionStore.markdown(for: decisions, now: date)
        #expect(markdown.hasPrefix("# iPhone Duo playbook\n\n1 of 10 topics decided · 2027-01-15"))
        #expect(markdown.contains("**Native tab bar** (Recommended)."))
        #expect(markdown.contains("Why: Matches the system\n"))
        #expect(markdown.contains("Adjusted: minimize=never"))
        #expect(markdown.contains("`duolab://topic/tabbar/native?minimize=never`"))
        #expect(markdown.components(separatedBy: "_Not decided yet._").count == 10)
    }
}
