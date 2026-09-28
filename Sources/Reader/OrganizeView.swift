import SwiftUI
import UniformTypeIdentifiers

struct OrganizeView: View {
    let tab: DocumentTab
    @State private var selection: Int?
    @State private var dropTarget: Int?

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Button(tr("Insérer depuis un fichier…"), systemImage: "doc.badge.plus") { tab.insertPages() }
                Divider().frame(height: 18)
                Group {
                    Group {
                        Button(tr("Déplacer vers la gauche"), systemImage: "arrow.left") { move(by: -1) }
                            .help(tr("Déplacer la page vers la gauche"))
                            .disabled(selection == 0)
                        Button(tr("Déplacer vers la droite"), systemImage: "arrow.right") { move(by: 1) }
                            .help(tr("Déplacer la page vers la droite"))
                            .disabled(selection == tab.pageCount - 1)
                    }
                    .labelStyle(.iconOnly)
                    Button(tr("Pivoter à gauche"), systemImage: "rotate.left") { if let selection { tab.rotatePage(selection, by: -90) } }
                    Button(tr("Pivoter à droite"), systemImage: "rotate.right") { if let selection { tab.rotatePage(selection, by: 90) } }
                    Button(tr("Supprimer"), systemImage: "trash") {
                        if let selection { tab.deletePage(selection) }
                        selection = nil
                    }
                }
                .disabled(selection == nil)
                Spacer()
                Text(tr("Glissez une page sur une autre pour la déplacer"))
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Button(tr("Terminer")) { tab.mode = .read }
                    .buttonStyle(.glassProminent)
            }
            .labelStyle(.titleAndIcon)
            .buttonStyle(.glass)
            .padding(.horizontal, 16)
            .frame(height: 52)
            .background(Color(nsColor: .windowBackgroundColor))
            Divider()

            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 20)], spacing: 24) {
                    ForEach(0..<tab.pageCount, id: \.self) { index in
                        pageCell(index)
                    }
                }
                .padding(28)
            }
        }
        .background(Color.canvas)
    }

    private func pageCell(_ index: Int) -> some View {
        let selected = selection == index
        let targeted = dropTarget == index
        return VStack(spacing: 8) {
            PageThumbnail(page: tab.pdf.page(at: index), width: 128)
                .id(tab.revision)
                .padding(10)
                .background {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(selected ? Color.accentColor.opacity(0.12) : .clear)
                        .strokeBorder(selected || targeted ? Color.accentColor : .clear,
                                      style: StrokeStyle(lineWidth: 2, dash: targeted && !selected ? [6, 4] : []))
                }
            Text("\(index + 1)")
                .font(.caption.monospacedDigit())
                .foregroundStyle(selected ? .primary : .secondary)
        }
        .contentShape(Rectangle())
        .onDrag {
            selection = index
            return NSItemProvider(object: String(index) as NSString)
        }
        // Un onTapGesture sur la même vue peut empêcher le glisser de démarrer sur macOS : le clic est simultané.
        .simultaneousGesture(TapGesture().onEnded { selection = index })
        .onDrop(of: [.plainText], delegate: PageDropDelegate(index: index, tab: tab, dropTarget: $dropTarget, selection: $selection))
    }

    private func move(by offset: Int) {
        guard let selection else { return }
        tab.movePage(from: selection, to: selection + offset)
        self.selection = selection + offset
    }
}

/// Déposer une page sur une autre : elle prend sa place.
private struct PageDropDelegate: DropDelegate {
    let index: Int
    let tab: DocumentTab
    @Binding var dropTarget: Int?
    @Binding var selection: Int?

    func dropEntered(info: DropInfo) { dropTarget = index }

    func dropExited(info: DropInfo) {
        if dropTarget == index { dropTarget = nil }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? { DropProposal(operation: .move) }

    func performDrop(info: DropInfo) -> Bool {
        dropTarget = nil
        guard let provider = info.itemProviders(for: [.plainText]).first else { return false }
        _ = provider.loadObject(ofClass: NSString.self) { object, _ in
            guard let from = (object as? NSString).flatMap({ Int($0 as String) }) else { return }
            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    tab.movePage(from: from, to: index)
                    selection = index
                }
            }
        }
        return true
    }
}
