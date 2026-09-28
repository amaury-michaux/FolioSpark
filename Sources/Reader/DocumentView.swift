import SwiftUI

struct DocumentView: View {
    @Bindable var tab: DocumentTab

    var body: some View {
        VStack(spacing: 0) {
            DocumentTopBar(tab: tab)
            Divider()
            HStack(spacing: 0) {
                if tab.showTools {
                    ToolsPanel(tab: tab).frame(width: 236)
                    Divider()
                }
                ZStack {
                    HStack(spacing: 0) {
                        QuickToolbar(tab: tab)
                            .padding(10)
                            .frame(maxHeight: .infinity, alignment: .top)
                        PDFKitView(tab: tab)
                    }
                    .background(Color.canvas)
                    if tab.mode == .organize {
                        OrganizeView(tab: tab)
                    }
                }
                if let panel = tab.panel {
                    Divider()
                    SidePanelView(tab: tab, panel: panel).frame(width: 290)
                }
                Divider()
                RightRail(tab: tab)
            }
        }
    }
}

// MARK: - Barre du haut

private struct DocumentTopBar: View {
    @Bindable var tab: DocumentTab
    @FocusState private var searchFocused: Bool

    var body: some View {
        HStack(spacing: 20) {
            TopTab(title: tr("Tous les outils"), active: tab.showTools) { tab.showTools.toggle() }
            TopTab(title: tr("Commenter"), active: tab.mode == .read && tab.panel == .comments) {
                tab.mode = .read
                tab.panel = tab.panel == .comments ? nil : .comments
            }
            TopTab(title: tr("Organiser les pages"), active: tab.mode == .organize) {
                tab.mode = tab.mode == .organize ? .read : .organize
            }
            Spacer()
            searchField
            HStack(spacing: 2) {
                IconButton(symbol: "square.and.arrow.down", help: tr("Enregistrer (⌘S)")) { tab.save() }
                    .disabled(!tab.isDirty)
                IconButton(symbol: "printer", help: tr("Imprimer (⌘P)")) { tab.printDocument() }
            }
            if let url = tab.url {
                ShareLink(item: url) { Text(tr("Partager")) }
                    .buttonStyle(.glassProminent)
            }
        }
        .padding(.horizontal, 18)
        .frame(height: 46)
    }

    private var searchField: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
            TextField(tr("Rechercher dans le document"), text: $tab.searchText)
                .textFieldStyle(.plain)
                .focused($searchFocused)
                .onSubmit { tab.search() }
            if !tab.results.isEmpty {
                Text("\(tab.resultIndex + 1) \(tr("sur")) \(tab.results.count)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 10)
        .frame(width: 280, height: 28)
        .background(Capsule().fill(Color.primary.opacity(0.06)))
        .onChange(of: tab.searchFocusRequest) { searchFocused = true }
    }
}

private struct TopTab: View {
    let title: String
    let active: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(active ? .primary : .secondary)
                .frame(maxHeight: .infinity)
                .overlay(alignment: .bottom) {
                    if active { Capsule().fill(.primary).frame(height: 2) }
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Tous les outils

private struct ToolsPanel: View {
    @Environment(AppModel.self) private var model
    let tab: DocumentTab

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(tr("Tous les outils")).font(.headline)
                Spacer()
                IconButton(symbol: "xmark", help: tr("Masquer les outils")) { tab.showTools = false }
            }
            .padding(.leading, 8)
            .padding(.bottom, 8)

            ToolRow(title: tr("Commenter"), symbol: "text.bubble", tint: .orange) {
                tab.mode = .read
                tab.panel = .comments
                tab.tool = .note
            }
            ToolRow(title: tr("Organiser les pages"), symbol: "square.grid.2x2", tint: .green) { tab.mode = .organize }
            ToolRow(title: tr("Combiner des fichiers"), symbol: "square.on.square", tint: .blue) { model.combineFiles() }
            ToolRow(title: tr("Compresser un PDF"), symbol: "arrow.down.right.and.arrow.up.left", tint: .red) { tab.compress() }
            ToolRow(title: tr("Protéger un PDF"), symbol: "lock", tint: .indigo) { tab.protect() }
            Divider().padding(.vertical, 6)
            ToolRow(title: tr("Exporter en texte"), symbol: "doc.plaintext", tint: .teal) { tab.exportText() }
            ToolRow(title: tr("Exporter en images"), symbol: "photo", tint: .teal) { tab.exportImages() }
            ToolRow(title: tr("Imprimer"), symbol: "printer", tint: .secondary) { tab.printDocument() }
            Spacer()
        }
        .padding(10)
    }
}

private struct ToolRow: View {
    let title: String
    let symbol: String
    let tint: Color
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: symbol)
                    .foregroundStyle(tint)
                    .frame(width: 20)
                Text(title)
                Spacer()
            }
            .font(.system(size: 13))
            .padding(.horizontal, 8)
            .frame(height: 32)
            .background(RoundedRectangle(cornerRadius: 7).fill(hovering ? Color.primary.opacity(0.07) : .clear))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}

// MARK: - Barre d'outils flottante

private struct QuickToolbar: View {
    @Bindable var tab: DocumentTab
    @State private var showColors = false

    var body: some View {
        VStack(spacing: 2) {
            ForEach(Tool.allCases, id: \.self) { tool in
                IconButton(symbol: tool.symbol, help: tool.label, active: tab.tool == tool) { tab.tool = tool }
                if tool == .select {
                    Divider().frame(width: 20).padding(.vertical, 3)
                }
            }
            if tab.tool.usesColor {
                Divider().frame(width: 20).padding(.vertical, 3)
                Button { showColors.toggle() } label: {
                    Circle()
                        .fill(Color(nsColor: tab.color))
                        .overlay(Circle().strokeBorder(.primary.opacity(0.2)))
                        .frame(width: 16, height: 16)
                        .frame(width: 30, height: 30)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help(tr("Couleur"))
                .popover(isPresented: $showColors, arrowEdge: .trailing) {
                    HStack(spacing: 10) {
                        ForEach(markupColors, id: \.self) { color in
                            Button {
                                tab.color = color
                                showColors = false
                            } label: {
                                Circle()
                                    .fill(Color(nsColor: color))
                                    .frame(width: 20, height: 20)
                                    .padding(3)
                                    .overlay {
                                        if color == tab.color { Circle().strokeBorder(.primary, lineWidth: 2) }
                                    }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(10)
                }
            }
        }
        .padding(5)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 14))
    }
}

// MARK: - Rail de droite

private struct RightRail: View {
    @Bindable var tab: DocumentTab
    @State private var pageText = "1"

    var body: some View {
        VStack(spacing: 4) {
            ForEach([SidePanel.pages, .comments, .bookmarks, .search], id: \.self) { panel in
                IconButton(symbol: panel.symbol, help: panel.title, active: tab.panel == panel) {
                    tab.panel = tab.panel == panel ? nil : panel
                }
            }
            Spacer()
            TextField("", text: $pageText)
                .textFieldStyle(.plain)
                .multilineTextAlignment(.center)
                .font(.system(size: 12).monospacedDigit())
                .frame(width: 32, height: 24)
                .background(RoundedRectangle(cornerRadius: 6).strokeBorder(Color.primary.opacity(0.2)))
                .onSubmit {
                    if let number = Int(pageText) { tab.go(to: number - 1) }
                    pageText = "\(tab.pageIndex + 1)"
                }
                .help(tr("Aller à la page"))
            Text("\(tab.pageCount)")
                .font(.system(size: 12).monospacedDigit())
                .foregroundStyle(.secondary)
                .padding(.bottom, 2)
            IconButton(symbol: "chevron.up", help: tr("Page précédente")) { tab.go(to: tab.pageIndex - 1) }
                .disabled(tab.pageIndex == 0)
            IconButton(symbol: "chevron.down", help: tr("Page suivante")) { tab.go(to: tab.pageIndex + 1) }
                .disabled(tab.pageIndex >= tab.pageCount - 1)
            Divider().frame(width: 24).padding(.vertical, 4)
            IconButton(symbol: "rotate.right", help: tr("Faire pivoter la page")) { tab.rotatePage(tab.pageIndex, by: 90) }
            IconButton(symbol: "plus.magnifyingglass", help: tr("Zoom avant (⌘+)")) { tab.zoomIn() }
            IconButton(symbol: "minus.magnifyingglass", help: tr("Zoom arrière (⌘−)")) { tab.zoomOut() }
        }
        .padding(.vertical, 10)
        .frame(width: 48)
        .onChange(of: tab.pageIndex, initial: true) { pageText = "\(tab.pageIndex + 1)" }
    }
}
