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
        let link = try #require(DeepLink.parse(url: URL(string: "duolab://tab/device")!))
        #expect(link.tab == .device)
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
        #expect(router.path == [.grids])
        #expect(router.preview?.optionID == "fixed-two")

        let other = AppRouter()
        other.handle(DeepLink(tab: .topics, lab: .grids, option: "nope"))
        #expect(other.preview == nil)
        #expect(other.banner != nil)
    }
}

struct TourTests {
    @Test func tourURL() throws {
        let link = try #require(DeepLink.parse(url: URL(string: "duolab://tour")!))
        #expect(link.tour == TourLaunch())
        #expect(link.lab == nil)
        #expect(link.errors.isEmpty)
    }

    @Test func tourURLWithStepPausedAndCompare() throws {
        let link = try #require(DeepLink.parse(url: URL(string: "duolab://tour/7?paused=1&compare=1")!))
        #expect(link.tour == TourLaunch(step: 7, paused: true, compare: true))
        #expect(link.knobs.isEmpty)
        let query = try #require(DeepLink.parse(url: URL(string: "duolab://tour?step=3")!))
        #expect(query.tour?.step == 3)
    }

    @Test func badTourStepIsAnErrorNotACrash() throws {
        let link = try #require(DeepLink.parse(url: URL(string: "duolab://tour/zero")!))
        #expect(link.tour?.step == 1)
        #expect(link.errors.count == 1)
    }

    @Test func tourLaunchArguments() throws {
        let args = ["/path/DuoLab", "-tour", "1", "-tourStep", "7", "-tourPaused", "1", "-duolab.hideBar", "1"]
        let link = try #require(DeepLink.parse(arguments: args))
        #expect(link.tour == TourLaunch(step: 7, paused: true, compare: false))
        #expect(link.errors.isEmpty)
        let compare = try #require(DeepLink.parse(arguments: ["-tour", "yes", "-tourCompare", "1"]))
        #expect(compare.tour == TourLaunch(step: 1, paused: false, compare: true))
    }

    @Test func tourStepWithoutTourDoesNothing() {
        #expect(DeepLink.parse(arguments: ["/path/DuoLab", "-tour", "0", "-tourStep", "4"]) == nil)
        #expect(DeepLink.parse(arguments: ["/path/DuoLab", "-tourStep", "4"]) == nil)
    }

    @Test func routerStartsTourAndClampsTheStep() {
        let router = AppRouter()
        router.handle(DeepLink(tour: TourLaunch(step: 3)))
        #expect(router.tour?.step == 3)
        #expect(router.banner == nil)

        let far = AppRouter()
        far.handle(DeepLink(tour: TourLaunch(step: 99)))
        #expect(far.tour?.step == TourStep.all.count)
        #expect(far.banner != nil)
    }

    @Test func openThisTopicRoutesAfterTheTourCloses() throws {
        let router = AppRouter()
        router.startTour()
        let target = PreviewTarget(lab: .grids, optionID: GridsLab.options[0].id)
        router.closeTour(opening: target)
        #expect(router.tour == nil)
        #expect(router.path.isEmpty)
        let exit = try #require(router.takeTourExit())
        #expect(exit == target)
        #expect(router.path == [.grids])
        #expect(router.takeTourExit() == nil)
    }

    @Test func stepsFollowTheCatalogWithTheRecommendedAnswer() {
        let steps = TourStep.all
        #expect(steps.map(\.lab) == LabID.catalog)
        for step in steps {
            #expect(step.option == step.lab.featuredOption)
            if step.lab.options.contains(where: { $0.verdict == .recommended }) {
                #expect(step.option.verdict == .recommended, "\(step.lab)")
            }
            #expect(step.avoid == nil || step.avoid?.verdict == .avoid)
        }
    }

    @Test func clockAdvancesHoldsOnTouchAndStopsAtTheEnd() {
        let start = Date(timeIntervalSinceReferenceDate: 0)
        let model = TourModel(launch: TourLaunch())
        // Not yet: 7.9 s in.
        for _ in 0..<79 { #expect(!model.tick(0.1, now: start, reduceMotion: false)) }
        #expect(model.tick(0.1, now: start, reduceMotion: false))
        model.go(1)
        #expect(model.index == 1 && model.elapsed == 0)

        model.touched(now: start)
        #expect(!model.tick(1, now: start.addingTimeInterval(4), reduceMotion: false))
        #expect(model.elapsed == 0)
        _ = model.tick(1, now: start.addingTimeInterval(5), reduceMotion: false)
        #expect(model.elapsed == 1)

        #expect(!model.tick(8, now: start, reduceMotion: true), "Reduce Motion never advances")

        let last = TourModel(launch: TourLaunch(step: TourStep.all.count))
        #expect(!last.tick(8, now: start, reduceMotion: false))
        #expect(last.userPaused)
        last.togglePlay()
        #expect(last.index == 0 && !last.userPaused)
    }

    @Test func pausedLaunchStaysPaused() {
        let model = TourModel(launch: TourLaunch(step: 7, paused: true))
        #expect(model.index == 6)
        #expect(!model.tick(8, reduceMotion: false))
        #expect(model.elapsed == 0)
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
