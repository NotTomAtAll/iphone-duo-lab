import SwiftUI

/// Neutral placeholder content: colored tiles, symbols and filler text.
enum Placeholder {
    static let symbols = [
        "leaf.fill", "cloud.sun.fill", "mountain.2.fill", "camera.macro", "bicycle", "cup.and.saucer.fill",
        "music.note", "paintpalette.fill", "book.closed.fill", "globe.europe.africa.fill", "tram.fill", "film.fill",
    ]

    static let names = [
        "Morning walk", "Harbor lights", "Quiet street", "Field notes", "Blue hour", "Market day",
        "Trail map", "Old station", "Paper boats", "North shore", "Studio", "Late train",
    ]

    static func color(_ index: Int) -> Color {
        Color(hue: Double((index * 37) % 360) / 360, saturation: 0.55, brightness: 0.85)
    }

    static func symbol(_ index: Int) -> String { symbols[abs(index) % symbols.count] }

    static func name(_ index: Int) -> String { names[abs(index) % names.count] }

    static let sentence = "Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua."

    static let paragraphs = [
        "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Integer posuere erat a ante venenatis dapibus posuere velit aliquet. Cras mattis consectetur purus sit amet fermentum. Donec ullamcorper nulla non metus auctor fringilla.",
        "Maecenas faucibus mollis interdum. Vestibulum id ligula porta felis euismod semper. Nullam quis risus eget urna mollis ornare vel eu leo. Aenean lacinia bibendum nulla sed consectetur. Sed posuere consectetur est at lobortis.",
        "Curabitur blandit tempus porttitor. Etiam porta sem malesuada magna mollis euismod. Praesent commodo cursus magna, vel scelerisque nisl consectetur et. Vivamus sagittis lacus vel augue laoreet rutrum faucibus dolor auctor.",
        "Duis mollis, est non commodo luctus, nisi erat porttitor ligula, eget lacinia odio sem nec elit. Morbi leo risus, porta ac consectetur ac, vestibulum at eros. Fusce dapibus, tellus ac cursus commodo, tortor mauris condimentum nibh.",
    ]
}

/// A colored tile with a symbol, used as photo/video stand-in.
struct Tile: View {
    let index: Int
    var showsCaption = true

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Placeholder.color(index).gradient)
            GeometryReader { proxy in
                let side = min(proxy.size.width, proxy.size.height) * 0.42
                Image(systemName: Placeholder.symbol(index))
                    .resizable()
                    .scaledToFit()
                    .fontWeight(.semibold)
                    .foregroundStyle(.white.opacity(0.9))
                    .frame(width: min(side, 64), height: min(side, 64))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            if showsCaption {
                Text(Placeholder.name(index))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(8)
            }
        }
    }
}

/// A short caption describing what to look for.
struct LookFor: View {
    let text: String

    var body: some View {
        Label(text, systemImage: "eye")
            .font(.footnote)
            .foregroundStyle(.secondary)
    }
}

extension EdgeInsets {
    var compact: String {
        "L\(Int(leading.rounded())) T\(Int(top.rounded())) R\(Int(trailing.rounded())) B\(Int(bottom.rounded()))"
    }
}

extension CGSize {
    var compact: String { "\(Int(width.rounded()))×\(Int(height.rounded()))" }
}

extension CGRect {
    var compact: String {
        "x\(Int(minX.rounded())) y\(Int(minY.rounded())) \(Int(width.rounded()))×\(Int(height.rounded()))"
    }
}
