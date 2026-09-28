import PDFKit
import SwiftUI

/// Bouton-icône carré utilisé partout (rail, barre flottante, barre du haut).
struct IconButton: View {
    let symbol: String
    let help: String
    var active = false
    let action: () -> Void

    @Environment(\.isEnabled) private var isEnabled
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 14))
                .foregroundStyle(active ? Color.accentColor : .primary)
                .frame(width: 30, height: 30)
                .background(RoundedRectangle(cornerRadius: 7).fill(
                    active ? Color.accentColor.opacity(0.15) : hovering && isEnabled ? Color.primary.opacity(0.07) : .clear))
                .contentShape(Rectangle())
                .opacity(isEnabled ? 1 : 0.35)
        }
        .buttonStyle(.plain)
        .help(help)
        .accessibilityLabel(help)
        .onHover { hovering = $0 }
    }
}

struct PageThumbnail: View {
    let page: PDFPage?
    let width: CGFloat

    var body: some View {
        if let page {
            let box = page.bounds(for: .cropBox)
            let ratio = page.rotation % 180 == 0 ? box.height / box.width : box.width / box.height
            Image(nsImage: page.thumbnail(of: NSSize(width: width * 2, height: width * 2 * ratio), for: .cropBox))
                .resizable()
                .frame(width: width, height: width * ratio)
                .background(.white)
                .clipShape(RoundedRectangle(cornerRadius: 2))
                .shadow(color: .black.opacity(0.18), radius: 2, y: 1)
        }
    }
}

extension Color {
    static let canvas = Color(nsColor: .readerCanvas)
}
