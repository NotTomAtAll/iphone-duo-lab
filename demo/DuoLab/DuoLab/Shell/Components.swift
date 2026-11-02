import SwiftUI
import UIKit

/// Which display a thumbnail imitates.
enum PreviewPose: String, CaseIterable, Identifiable {
    case open, folded

    var id: String { rawValue }

    var title: String { self == .open ? "Open" : "Folded" }

    var symbol: String { self == .open ? "rectangle.split.2x1" : "iphone" }

    /// Measured window sizes on the iPhone Duo simulator (iOS 27.1).
    var canvas: CGSize { self == .open ? CGSize(width: 951, height: 669) : CGSize(width: 466, height: 678) }

    /// The 84 pt trailing rail holds the status bar and cameras on both displays.
    static let railWidth: CGFloat = 84

    /// Stand-in fold for the open display, in canvas points.
    var fold: CGRect? {
        self == .open ? CGRect(x: canvas.width / 2 - 14, y: 0, width: 28, height: canvas.height) : nil
    }
}

/// A miniature of an option, rendered at the real window size in an isolated window.
struct OptionThumbnail: View {
    let lab: LabID
    let values: [String: String]
    let pose: PreviewPose
    private let renderer = ThumbnailRenderer.shared
    @Environment(\.colorScheme) private var scheme

    init(lab: LabID, option: LabOption, pose: PreviewPose, tweaks: [String: String] = [:]) {
        self.lab = lab
        self.pose = pose
        self.values = option.knobs.merging(tweaks) { $1 }
    }

    var body: some View {
        let canvas = pose.canvas
        let image = renderer.images[ThumbnailRenderer.key(lab: lab, values: values, pose: pose, scheme: scheme)]
        Color(.secondarySystemBackground)
            .aspectRatio(canvas.width / canvas.height, contentMode: .fit)
            .overlay {
                if let image {
                    Image(uiImage: image).resizable().interpolation(.high).transition(.opacity)
                } else {
                    ProgressView()
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(.separator, lineWidth: 0.5)
            )
            .animation(.easeOut(duration: 0.2), value: image != nil)
            .onAppear { renderer.request(lab: lab, values: values, pose: pose, scheme: scheme) }
            .onChange(of: scheme) { _, new in renderer.request(lab: lab, values: values, pose: pose, scheme: new) }
            .accessibilityHidden(true)
    }

}

struct VerdictChip: View {
    let verdict: Verdict
    var compact = false

    var body: some View {
        Label(verdict.title, systemImage: verdict.symbol)
            .lineLimit(1)
            .font(compact ? .caption2.weight(.semibold) : .caption.weight(.semibold))
            .foregroundStyle(verdict.color)
            .padding(.horizontal, compact ? 6 : 8)
            .padding(.vertical, compact ? 2 : 4)
            .background(verdict.color.opacity(0.12), in: .capsule)
    }
}

struct ChosenBadge: View {
    var body: some View {
        Label("Chosen", systemImage: "checkmark.circle.fill")
            .font(.caption.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.tint, in: .capsule)
    }
}

/// A grouped-style card surface.
struct CardBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

extension View {
    func card() -> some View { modifier(CardBackground()) }
}

/// Even column count that fits the width: a gutter, not a card, lands on the fold.
func evenColumns(for width: CGFloat, minimum: CGFloat, spacing: CGFloat = 16) -> [GridItem] {
    var count = max(1, Int((width + spacing) / (minimum + spacing)))
    if count > 1, count % 2 == 1 { count -= 1 }
    return Array(repeating: GridItem(.flexible(), spacing: spacing, alignment: .top), count: count)
}
