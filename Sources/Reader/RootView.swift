import SwiftUI
import UniformTypeIdentifiers

struct RootView: View {
    @Environment(AppModel.self) private var model
    @State private var dropTargeted = false

    var body: some View {
        VStack(spacing: 0) {
            TabStrip()
            // Chaque onglet reste monté pour conserver sa position de lecture.
            ZStack {
                layer(HomeView(), visible: model.selectedID == nil)
                ForEach(model.tabs) { tab in
                    layer(DocumentView(tab: tab), visible: tab.id == model.selectedID)
                }
            }
        }
        .ignoresSafeArea(.container, edges: .top)
        .background(Color(nsColor: .windowBackgroundColor))
        .dropDestination(for: URL.self) { urls, _ in
            let pdfs = urls.filter { $0.pathExtension.lowercased() == "pdf" }
            pdfs.forEach(model.open)
            return !pdfs.isEmpty
        } isTargeted: { dropTargeted = $0 }
        .overlay {
            if dropTargeted {
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(Color.accentColor, style: StrokeStyle(lineWidth: 2, dash: [7, 5]))
                    .padding(6)
                    .allowsHitTesting(false)
            }
        }
    }

    private func layer(_ content: some View, visible: Bool) -> some View {
        content.opacity(visible ? 1 : 0).allowsHitTesting(visible).accessibilityHidden(!visible)
    }
}

// MARK: - Barre d'onglets

struct TabStrip: View {
    @Environment(AppModel.self) private var model
    @State private var language = LanguageStore.shared

    var body: some View {
        HStack(spacing: 4) {
            Color.clear.frame(width: 72, height: 1) // feux de fenêtre
            IconButton(symbol: "house", help: tr("Accueil"), active: model.selectedID == nil) {
                model.selectedID = nil
            }
            ForEach(model.tabs) { tab in
                TabItem(tab: tab)
            }
            IconButton(symbol: "plus", help: tr("Ouvrir un fichier (⌘O)")) { model.presentOpenPanel() }
            Spacer(minLength: 0)
            Menu {
                ForEach(AppLanguage.allCases, id: \.self) { option in
                    Button(option.name) { language.selection = option }
                }
            } label: {
                Text(language.selection.rawValue.uppercased())
                    .font(.system(size: 11, weight: .semibold))
                    .frame(width: 36, height: 26)
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .help(tr("Langue"))
        }
        .padding(.horizontal, 8)
        .frame(height: 34)
        .background {
            Color.primary.opacity(0.05)
                .contentShape(Rectangle())
                .gesture(WindowDragGesture())
                .simultaneousGesture(TapGesture(count: 2).onEnded { NSApp.keyWindow?.performZoom(nil) })
        }
    }
}

private struct TabItem: View {
    @Environment(AppModel.self) private var model
    let tab: DocumentTab
    @State private var hovering = false

    var body: some View {
        let selected = model.selectedID == tab.id
        let showDot = tab.isDirty && !hovering
        HStack(spacing: 7) {
            Image(nsImage: NSWorkspace.shared.icon(for: .pdf))
                .resizable()
                .frame(width: 16, height: 16)
            Text(tab.title)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer(minLength: 2)
            Button { model.close(tab) } label: {
                Image(systemName: showDot ? "circle.fill" : "xmark")
                    .font(.system(size: showDot ? 6 : 9, weight: .bold))
                    .frame(width: 18, height: 18)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .opacity(selected || hovering || tab.isDirty ? 1 : 0)
            .help(tr("Fermer l’onglet (⌘W)"))
            .accessibilityLabel(tab.isDirty ? tr("Fermer l’onglet (modifications non enregistrées)") : tr("Fermer l’onglet"))
        }
        .font(.system(size: 12, weight: .medium))
        .foregroundStyle(selected ? .primary : .secondary)
        .padding(.leading, 10)
        .padding(.trailing, 5)
        .frame(minWidth: 110, maxWidth: 230, minHeight: 28, maxHeight: 28)
        .background {
            RoundedRectangle(cornerRadius: 8)
                .fill(selected ? Color(nsColor: .windowBackgroundColor) : hovering ? Color.primary.opacity(0.06) : .clear)
                .shadow(color: .black.opacity(selected ? 0.1 : 0), radius: 1, y: 0.5)
        }
        .contentShape(Rectangle())
        .onTapGesture { model.selectedID = tab.id }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(tab.title)
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
        .accessibilityAction { model.selectedID = tab.id }
        .onHover { hovering = $0 }
        .help(tab.url?.path ?? tab.title)
        .contextMenu {
            Button(tr("Fermer l’onglet")) { model.close(tab) }
            if let url = tab.url {
                Button(tr("Afficher dans le Finder")) { NSWorkspace.shared.activateFileViewerSelecting([url]) }
            }
        }
    }
}
