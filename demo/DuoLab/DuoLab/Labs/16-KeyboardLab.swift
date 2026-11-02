import SwiftUI
import UIKit

enum KeyboardLab {
    static let options: [LabOption] = [
        LabOption("composer-above-keyboard", "Field rides on the keyboard", .recommended,
                  summary: "The message field sits at the bottom and moves up with the keyboard; the messages scroll so the newest stays in view.",
                  pros: ["The field is never hidden, whatever size the keyboard is", "No keyboard height to guess", "The newest message stays just above the field"],
                  cons: ["One pane: on the open display it stretches across the fold"],
                  lookFor: "Closed: tap the field. It lifts with the keyboard and the readout says Clear. Then open the device: the keyboard should stay up.",
                  highlight: "composer"),
        LabOption("composer-in-pane", "Field in the message pane", .recommended,
                  summary: "Open: a list of chats on one side of the fold, the conversation and its field on the other. The keyboard spans the window; the field stays in its pane.",
                  pros: ["The field stays next to the messages it belongs to", "Clear of the fold", "Same field behaviour as on the phone"],
                  cons: ["Two layouts to build"],
                  lookFor: "Open: the field starts right of the fold and lifts with the keyboard. Closed: one pane, same as the option before.",
                  knobs: ["layout": "auto"], highlight: "composer"),
        LabOption("fixed-bottom", "Field fixed at the bottom", .avoid,
                  summary: "The field is pinned to the bottom of the screen and ignores the keyboard.",
                  pros: ["Simple"],
                  cons: ["The keyboard covers the field you are typing in", "You type blind"],
                  lookFor: "Tap the field: the keyboard comes up over it and the readout says Covered.",
                  knobs: ["composer": "fixed"], highlight: "composer"),
        LabOption("full-width-composer", "Field across both panes", .avoid,
                  summary: "Two panes, but one field runs along the bottom of both, across the fold.",
                  pros: ["Wide field for long messages"],
                  cons: ["The fold runs through the field and its buttons", "Unclear which pane it belongs to"],
                  lookFor: "Open: the field starts under the chat list and ends under the conversation, with the fold through it.",
                  knobs: ["layout": "auto", "composer": "window"], highlight: "composer"),
    ]

    static let knobs: [KnobSpec] = [
        KnobSpec("composer", "Message field", options: [
            .init("keyboard", "Above the keyboard"), .init("fixed", "Fixed bottom, ignores keyboard"),
            .init("window", "Across the whole window"),
        ], note: "SwiftUI moves content out of the keyboard's way by default; in UIKit pin the field to the keyboard layout guide. Never use a guessed keyboard height: it differs per display and pose.",
        facts: []),
        KnobSpec("layout", "Layout", options: [.init("single", "One pane everywhere"), .init("auto", "Two panes when open")],
                 note: "On the open display a conversation belongs in its own pane, next to the list of chats.",
                 facts: ["F-3a"]),
        .toggle("refocus", "Keep typing across a fold", default: true,
                note: "Switching between one pane and two panes rebuilds the field, which drops focus and the keyboard. On: the screen remembers you were typing and focuses the new field."),
        .toggle("readout", "Keyboard readout", default: true,
                note: "Shows the keyboard frame from the system, the bottom safe area and the keyboard layout guide, so you can compare them per pose."),
    ]
}

// MARK: - Keyboard measurements

/// What the system says about the keyboard, three ways.
@MainActor
@Observable
final class KeyboardReadings {
    /// From the keyboard frame notifications, in screen points.
    var frame: CGRect = .zero
    var screen: CGSize = .zero
    /// The bottom safe-area inset the content sees.
    var safeBottom: CGFloat = 0
    /// Height of the UIKit keyboard layout guide in a full-window view.
    var guide: CGFloat = 0
    var guideUndocked = false
    /// The field's frame in the window.
    var field: CGRect = .zero

    var visible: Bool { frame.height > 0 && frame.minY < screen.height }

    /// Points of the field under the keyboard (0 = clear).
    var fieldCovered: CGFloat {
        guard visible, field.height > 0 else { return 0 }
        return max(0, field.maxY - frame.minY)
    }
}

/// A full-window UIKit view that reports its keyboard layout guide.
private struct KeyboardGuideProbe: UIViewRepresentable {
    let readings: KeyboardReadings

    func makeUIView(context: Context) -> ProbeView {
        let view = ProbeView()
        view.onChange = { height, undocked in
            Task { @MainActor in
                readings.guide = height
                readings.guideUndocked = undocked
            }
        }
        return view
    }

    func updateUIView(_ uiView: ProbeView, context: Context) {}

    final class ProbeView: UIView {
        var onChange: ((CGFloat, Bool) -> Void)?
        private let marker = UIView()
        private var last: CGFloat = -1

        override init(frame: CGRect) {
            super.init(frame: frame)
            isUserInteractionEnabled = false
            keyboardLayoutGuide.followsUndockedKeyboard = true
            marker.translatesAutoresizingMaskIntoConstraints = false
            addSubview(marker)
            NSLayoutConstraint.activate([
                marker.leadingAnchor.constraint(equalTo: leadingAnchor),
                marker.widthAnchor.constraint(equalToConstant: 1),
                marker.topAnchor.constraint(equalTo: keyboardLayoutGuide.topAnchor),
                marker.bottomAnchor.constraint(equalTo: bottomAnchor),
            ])
        }

        required init?(coder: NSCoder) { nil }

        override func layoutSubviews() {
            super.layoutSubviews()
            let height = keyboardLayoutGuide.layoutFrame.height
            guard height != last else { return }
            last = height
            onChange?(height, keyboardLayoutGuide.layoutFrame.width < bounds.width - 1)
        }
    }
}

// MARK: - Lab view

struct KeyboardLabView: View {
    let state: KnobState

    var body: some View {
        KeyboardDemo(composer: state["composer"], split: state["layout"] == "auto", readout: state.isOn("readout"),
                     refocus: state.isOn("refocus"))
            .id(state.variantKey)
    }
}

private struct ChatMessage: Identifiable, Equatable {
    let id: Int
    let text: String
    let mine: Bool
}

private struct KeyboardDemo: View {
    let composer: String
    let split: Bool
    let readout: Bool
    let refocus: Bool
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.isThumbnail) private var isThumbnail
    @State private var readings = KeyboardReadings()
    @State private var messages: [ChatMessage] = (0..<14).map {
        ChatMessage(id: $0, text: String(Placeholder.sentence.prefix(30 + ($0 * 23) % 90)), mine: $0 % 3 == 1)
    }
    @State private var draft = ""
    @FocusState private var focused: Bool
    /// Lives above the layout switch: whether the person was typing, kept through a rebuild.
    @State private var typing = false
    @State private var lastLayoutChange = Date.distantPast

    /// Capture hook: `-duolab.focusComposer 1` focuses the field at launch.
    private static let autoFocus = UserDefaults.standard.bool(forKey: "duolab.focusComposer")

    /// Thumbnails can't show a keyboard; they draw one this tall (measured on the simulator).
    private var standInHeight: CGFloat { sizeClass == .regular ? 264 : 289 }
    private var tracksKeyboard: Bool { composer != "fixed" }

    var body: some View {
        Group {
            if split && sizeClass == .regular {
                FoldLocator { size, gutter, reported in
                    twoPanes(size: size, gutter: gutter, reported: reported)
                }
            } else {
                onePane
            }
        }
        .safeAreaPadding(.bottom, isThumbnail && tracksKeyboard ? standInHeight : 0)
        .overlay(alignment: .bottom) {
            if isThumbnail { KeyboardStandIn().frame(height: standInHeight) }
        }
        .background {
            GeometryReader { proxy in
                Color.clear
                    .onAppear { readings.safeBottom = proxy.safeAreaInsets.bottom }
                    .onChange(of: proxy.safeAreaInsets.bottom) { _, new in readings.safeBottom = new }
            }
        }
        .background { KeyboardGuideProbe(readings: readings).ignoresSafeArea() }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillChangeFrameNotification)) { note in
            guard let frame = note.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return }
            readings.frame = frame
            if let screen = (note.object as? UIScreen) ?? UIApplication.shared.connectedScenes
                .compactMap({ ($0 as? UIWindowScene)?.screen }).first {
                readings.screen = screen.bounds.size
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardDidHideNotification)) { _ in
            readings.frame = .zero
        }
        .onChange(of: focused) { _, now in
            if now { typing = true; return }
            // A field torn down by a layout change also loses focus; only a real dismissal counts.
            Task {
                try? await Task.sleep(for: .milliseconds(300))
                if !focused, Date.now.timeIntervalSince(lastLayoutChange) > 1.2 { typing = false }
            }
        }
        .onChange(of: sizeClass) {
            lastLayoutChange = .now
            guard refocus, typing else { return }
            Task {
                // Wait for the resize to settle; focus asked for mid-resize gets the cursor but no keyboard.
                try? await Task.sleep(for: .milliseconds(900))
                focused = false
                try? await Task.sleep(for: .milliseconds(50))
                focused = true
            }
        }
        .task {
            guard Self.autoFocus, !isThumbnail else { return }
            try? await Task.sleep(for: .milliseconds(700))
            focused = true
        }
    }

    // MARK: Layouts

    @ViewBuilder
    private var onePane: some View {
        switch composer {
        case "fixed":
            conversation
                .safeAreaPadding(.bottom, 64)
                .overlay(alignment: .bottom) { field }
                .ignoresSafeArea(.keyboard)
        default:
            conversation
                .safeAreaInset(edge: .bottom, spacing: 0) { field }
        }
    }

    @ViewBuilder
    private func twoPanes(size: CGSize, gutter: CGRect?, reported: Bool) -> some View {
        let fold = gutter ?? CGRect(x: size.width * 0.4, y: 0, width: 1, height: size.height)
        let panes = HStack(spacing: 0) {
            ChatList().frame(width: max(0, fold.minX))
            FoldGutter(reported: reported).frame(width: fold.width)
            if composer == "window" {
                conversation
            } else if composer == "fixed" {
                conversation
                    .safeAreaPadding(.bottom, 64)
                    .overlay(alignment: .bottom) { field }
            } else {
                conversation.safeAreaInset(edge: .bottom, spacing: 0) { field }
            }
        }
        switch composer {
        case "window": panes.safeAreaInset(edge: .bottom, spacing: 0) { field }
        case "fixed": panes.ignoresSafeArea(.keyboard)
        default: panes
        }
    }

    private var conversation: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(messages) { Bubble(message: $0).id($0.id) }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
            }
            .defaultScrollAnchor(.bottom)
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: messages.count) {
                withAnimation(.snappy) { proxy.scrollTo(messages.last?.id, anchor: .bottom) }
            }
            .onChange(of: readings.frame) {
                // Keep the newest message above the field when the keyboard comes or goes.
                proxy.scrollTo(messages.last?.id, anchor: .bottom)
            }
        }
        .overlay(alignment: .topLeading) {
            if readout { ReadoutCard(readings: readings, thumbnail: isThumbnail, composer: composer, standIn: standInHeight).padding(10) }
        }
    }

    private var field: some View {
        HStack(spacing: 10) {
            Button("Add", systemImage: "plus") {}
                .labelStyle(.iconOnly)
                .font(.title3)
            TextField("Message", text: $draft, axis: .vertical)
                .lineLimit(1...4)
                .focused($focused)
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(.fill.tertiary, in: .capsule)
                .submitLabel(.send)
                .onSubmit(send)
                .accessibilityIdentifier("keyboard.field")
            Button("Send", systemImage: "arrow.up.circle.fill", action: send)
                .labelStyle(.iconOnly)
                .font(.title)
                .disabled(draft.isEmpty)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.bar)
        .overlay(alignment: .top) { Rectangle().fill(.separator).frame(height: 0.5) }
        .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { readings.field = $0 }
    }

    private func send() {
        guard !draft.isEmpty else { return }
        messages.append(ChatMessage(id: messages.count, text: draft, mine: true))
        draft = ""
    }
}

// MARK: - Pieces

private struct Bubble: View {
    let message: ChatMessage

    var body: some View {
        HStack {
            if message.mine { Spacer(minLength: 40) }
            Text(message.text)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .foregroundStyle(message.mine ? .white : .primary)
                .background(message.mine ? Color.accentColor : Color(.secondarySystemBackground), in: .rect(cornerRadius: 18))
            if !message.mine { Spacer(minLength: 40) }
        }
    }
}

private struct ChatList: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                ForEach(0..<12, id: \.self) { index in
                    HStack(spacing: 12) {
                        Circle().fill(Placeholder.color(index).gradient).frame(width: 40, height: 40)
                            .overlay { Image(systemName: Placeholder.symbol(index)).foregroundStyle(.white) }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(Placeholder.name(index)).font(.headline)
                            Text(Placeholder.sentence).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 14)
                    .frame(height: 62)
                    .background(index == 0 ? Color.accentColor.opacity(0.16) : .clear)
                }
            }
        }
        .background(Color(.secondarySystemBackground).opacity(0.5))
    }
}

/// A flat drawing of a keyboard, for thumbnails only.
private struct KeyboardStandIn: View {
    var body: some View {
        VStack(spacing: 8) {
            ForEach(0..<4, id: \.self) { row in
                HStack(spacing: 6) {
                    ForEach(0..<(row == 3 ? 3 : 10 - row), id: \.self) { key in
                        RoundedRectangle(cornerRadius: 6)
                            .fill(.background.opacity(0.9))
                            .frame(maxWidth: row == 3 && key == 1 ? .infinity : 44)
                    }
                }
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGray4))
        .overlay(alignment: .top) {
            Text("KEYBOARD (EXAMPLE)").font(.caption2.bold()).foregroundStyle(.secondary).padding(.top, 2)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

private struct ReadoutCard: View {
    let readings: KeyboardReadings
    let thumbnail: Bool
    let composer: String
    let standIn: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Label("Keyboard", systemImage: "keyboard").font(.caption.weight(.semibold))
            if thumbnail {
                line("Height", "\(Int(standIn)) (example)")
                status(covered: composer == "fixed" ? 52 : 0)
            } else {
                line("System frame", readings.visible ? readings.frame.compact : "hidden")
                line("Safe area bottom", "\(Int(readings.safeBottom.rounded()))")
                line("Layout guide", "\(Int(readings.guide.rounded()))" + (readings.guideUndocked ? " undocked" : ""))
                line("Screen", readings.screen == .zero ? "–" : readings.screen.compact)
                status(covered: readings.fieldCovered)
            }
        }
        .font(.caption2.monospacedDigit())
        .padding(8)
        .frame(width: 210, alignment: .leading)
        .background(.regularMaterial, in: .rect(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(.white.opacity(0.15)))
        .shadow(color: .black.opacity(0.12), radius: 6, y: 2)
        .allowsHitTesting(false)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("keyboard.readout")
    }

    private func line(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title).foregroundStyle(.secondary)
            Spacer(minLength: 6)
            Text(value)
        }
    }

    @ViewBuilder
    private func status(covered: CGFloat) -> some View {
        if covered > 0 {
            Label("Field covered by \(Int(covered)) pt", systemImage: "xmark.circle.fill").foregroundStyle(.red)
        } else {
            Label("Field clear of keyboard", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
        }
    }
}
