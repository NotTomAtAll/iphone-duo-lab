import SwiftUI

enum ReadingLab {
    static let options: [LabOption] = [
        LabOption("column", "Readable column", .recommended,
                  summary: "Text keeps a comfortable book-like width, with the title lined up.",
                  pros: ["Comfortable line length on the inner display", "Unchanged on the folded phone"],
                  cons: ["Empty margins on wide screens, by design"],
                  lookFor: "Line length on the open display stays like a book page."),
        LabOption("form", "Narrow form", .recommended,
                  summary: "A settings form at a comfortable width.",
                  pros: ["Fields stay a sensible width", "Labels stay near their fields"],
                  cons: [],
                  lookFor: "Field widths on the open display.",
                  knobs: ["width": "480", "content": "form"]),
        LabOption("full-width", "Full-width text", .avoid,
                  summary: "Text stretches across the whole display.",
                  pros: ["No code"],
                  cons: ["Lines too long to read", "Text runs across the fold"],
                  lookFor: "Try to read a paragraph on the open display.",
                  knobs: ["width": "full"]),
        LabOption("misaligned", "Column, header left behind", .avoid,
                  summary: "The text is narrowed but the title still starts at the far left.",
                  pros: [],
                  cons: ["Title and text look unrelated", "The most common half-done fix"],
                  lookFor: "The title starts far left of the text.",
                  knobs: ["alignHeader": "off"]),
    ]

    static let knobs: [KnobSpec] = [
        KnobSpec("width", "Max width", options: [
            .init("full", "Full width"), .init("480", "480 pt"), .init("560", "560 pt"), .init("600", "600 pt"),
        ], default: "560",
        note: "A readable column is for forms and long text only. Feeds, grids, media and chat should use the width.",
        facts: ["D4", "R-§1"]),
        KnobSpec("content", "Content", options: [.init("article", "Article"), .init("form", "Form")],
                 note: "A 951 pt text field or line of text is hard to use. Both cases want a cap.",
                 facts: ["D4"]),
        .toggle("alignHeader", "Align header to column", default: true,
                note: "If only the body is capped, the title and the back button drift away from the text. Align them together.",
                facts: ["R-§1"]),
    ]
}

struct ReadingLabView: View {
    let state: KnobState

    private var maxWidth: CGFloat { CGFloat(Double(state["width"]) ?? .infinity) }
    /// The width the text column really gets, which is less than the cap on a narrow window.
    @State private var columnWidth: CGFloat = 0

    private var columnText: String {
        let full = state["width"] == "full"
        // Before the first layout pass (thumbnails can be captured then) only the cap is known.
        guard columnWidth > 0 else { return full ? "Column: full width" : "Column: up to \(state["width"]) pt" }
        let now = "\(Int(columnWidth.rounded())) pt"
        return full ? "Column: full width, \(now)" : "Column: \(now), up to \(state["width"]) pt"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header
                        .frame(maxWidth: state.isOn("alignHeader") ? maxWidth : .infinity, alignment: .leading)
                        .frame(maxWidth: .infinity, alignment: state.isOn("alignHeader") ? .center : .leading)
                    Group {
                        if state["content"] == "form" { form } else { article }
                    }
                    .frame(maxWidth: maxWidth, alignment: .leading)
                    .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { columnWidth = $0 }
                    .frame(maxWidth: .infinity)
                }
                .padding()
            }
            .navigationTitle("Reading")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(state["content"] == "form" ? "Account details" : "Field notes from the harbor")
                .font(.largeTitle.bold())
            Text(columnText)
                .font(.subheadline).foregroundStyle(.secondary)
        }
    }

    private var article: some View {
        VStack(alignment: .leading, spacing: 16) {
            Tile(index: 4).frame(height: 220)
            ForEach(Placeholder.paragraphs + Placeholder.paragraphs, id: \.self) { Text($0).font(.body) }
        }
    }

    private var form: some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(["Display name", "Email", "Phone", "City"], id: \.self) { field in
                VStack(alignment: .leading, spacing: 4) {
                    Text(field).font(.subheadline.weight(.semibold))
                    TextField(field, text: .constant(""))
                        .textFieldStyle(.roundedBorder)
                }
            }
            Toggle("Email me updates", isOn: .constant(true))
            Button("Save") {}
                .buttonStyle(.glassProminent)
                .controlSize(.large)
                .frame(maxWidth: .infinity)
        }
    }
}
