import Foundation

/// Every lab in the catalog. The raw value is the deep-link id.
enum LabID: String, CaseIterable, Identifiable, Codable, Sendable {
    case tabBar = "tabbar"
    case toolbars
    case listDetail = "listdetail"
    case grids
    case reading
    case media
    case overlays
    case sheets
    case hinge
    case antiPatterns = "antipatterns"
    case continuity = "continuity"
    case laptopPose = "laptop"
    case motion = "motion"
    case toasts = "toasts"
    case twoPanes = "twopanes"
    case keyboard = "keyboard"
    case transitions = "transitions"
    case camera = "camera"
    case narrowWindows = "narrow"

    var id: String { rawValue }

    var number: Int { (Self.allCases.firstIndex(of: self) ?? 0) + 1 }

    var numberText: String { String(format: "%02d", number) }

    var title: String {
        switch self {
        case .tabBar: "Tab bar"
        case .toolbars: "Toolbars and nav bars"
        case .listDetail: "List and detail"
        case .grids: "Grids and carousels"
        case .reading: "Reading width"
        case .media: "Media and side panel"
        case .overlays: "Floating overlays"
        case .sheets: "Presentations"
        case .hinge: "Hinge effects"
        case .antiPatterns: "Pitfalls"
        case .continuity: "Fold mid-task"
        case .laptopPose: "Laptop pose"
        case .motion: "Motion on fold"
        case .toasts: "Toasts and banners"
        case .twoPanes: "Two panes and drag"
        case .keyboard: "Keyboard per pose"
        case .transitions: "Transitions"
        case .camera: "Camera per pose"
        case .narrowWindows: "Small windows"
        }
    }

    var question: String {
        switch self {
        case .tabBar: "How should the tab bar behave when the phone folds and opens?"
        case .toolbars: "Where do the screen\u{2019}s action buttons go?"
        case .listDetail: "Should a list and the item you open sit side by side?"
        case .grids: "How should a photo grid use the big display?"
        case .reading: "How wide should text and forms be?"
        case .media: "Where does chat go next to a video?"
        case .overlays: "How do floating controls stay clear of the fold?"
        case .sheets: "Where do sheets, popovers and alerts appear?"
        case .hinge: "What can the fold angle bring to life?"
        case .antiPatterns: "What breaks first on a foldable, and how do you fix it?"
        case .continuity: "I was in the middle of something and opened the phone. Did anything get lost?"
        case .laptopPose: "Half open on a table: what goes in the top half and what in the bottom?"
        case .motion: "Should the layout animate when I open the phone, and how much?"
        case .toasts: "Where should a \u{201c}Saved\u{201d} message appear on each display and pose?"
        case .twoPanes: "Can two screens live side by side, and can I drag between them?"
        case .keyboard: "Where does the keyboard go, and what happens to what I was typing?"
        case .transitions: "Which transitions feel right on a foldable, and which get in the way?"
        case .camera: "Where do the preview and the shutter go when the phone is half open?"
        case .narrowWindows: "What happens when the app gets a short or narrow window: Split View, a floating video, or the old compatibility size?"
        }
    }

    var symbol: String {
        switch self {
        case .tabBar: "dock.rectangle"
        case .toolbars: "menubar.rectangle"
        case .listDetail: "sidebar.left"
        case .grids: "square.grid.3x2"
        case .reading: "text.alignleft"
        case .media: "play.rectangle.on.rectangle"
        case .overlays: "pip"
        case .sheets: "rectangle.bottomhalf.inset.filled"
        case .hinge: "book.pages"
        case .antiPatterns: "exclamationmark.triangle"
        case .continuity: "arrow.triangle.2.circlepath"
        case .laptopPose: "laptopcomputer"
        case .motion: "wand.and.sparkles"
        case .toasts: "text.bubble"
        case .twoPanes: "rectangle.split.2x1"
        case .keyboard: "keyboard"
        case .transitions: "arrow.up.left.and.arrow.down.right"
        case .camera: "camera"
        case .narrowWindows: "rectangle.compress.vertical"
        }
    }

    var facts: [String] {
        switch self {
        case .tabBar: ["T-6", "T-7", "T-8", "T-21", "T-31", "F-6a"]
        case .toolbars: ["F-3c", "F-6a", "T-19"]
        case .listDetail: ["F-4a", "D1"]
        case .grids: ["F-6b", "D1"]
        case .reading: ["D4"]
        case .media: ["F-3b", "D11"]
        case .overlays: ["F-3a", "F-6b", "D8", "D11"]
        case .sheets: ["F-6b"]
        case .hinge: ["F-3d"]
        case .antiPatterns: ["F-2e", "F-3f", "F-3g", "D10", "R-§1"]
        case .continuity: []
        case .laptopPose: []
        case .motion: []
        case .toasts: []
        case .twoPanes: []
        case .keyboard: []
        case .transitions: []
        case .camera: []
        case .narrowWindows: []
        }
    }

    var knobs: [KnobSpec] {
        switch self {
        case .tabBar: TabBarLab.knobs
        case .toolbars: ToolbarsLab.knobs
        case .listDetail: ListDetailLab.knobs
        case .grids: GridsLab.knobs
        case .reading: ReadingLab.knobs
        case .media: MediaLab.knobs
        case .overlays: OverlaysLab.knobs
        case .sheets: SheetsLab.knobs
        case .hinge: HingeLab.knobs
        case .antiPatterns: AntiPatternsLab.knobs
        case .continuity: ContinuityLab.knobs
        case .laptopPose: LaptopPoseLab.knobs
        case .motion: MotionLab.knobs
        case .toasts: ToastsLab.knobs
        case .twoPanes: TwoPanesLab.knobs
        case .keyboard: KeyboardLab.knobs
        case .transitions: TransitionsLab.knobs
        case .camera: CameraLab.knobs
        case .narrowWindows: NarrowWindowsLab.knobs
        }
    }
}

enum RootTab: String, CaseIterable, Hashable, Sendable {
    case topics, device
}
