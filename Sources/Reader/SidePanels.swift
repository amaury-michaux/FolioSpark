import PDFKit
import SwiftUI

struct SidePanelView: View {
    let tab: DocumentTab
    let panel: SidePanel

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(panel.title).font(.headline)
                Spacer()
                IconButton(symbol: "xmark", help: tr("Fermer le panneau")) { tab.panel = nil }
            }
            .padding(.leading, 14)
            .padding(.trailing, 8)
            .frame(height: 44)
            Divider()
            Group {
                switch panel {
                case .pages: PagesPanel(tab: tab)
                case .comments: CommentsPanel(tab: tab)
                case .bookmarks: BookmarksPanel(tab: tab)
                case .search: SearchPanel(tab: tab)
                }
            }
            .frame(maxHeight: .infinity)
        }
    }
}

// MARK: - Pages

private struct PagesPanel: View {
    let tab: DocumentTab

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(0..<tab.pageCount, id: \.self) { index in
                        let current = index == tab.pageIndex
                        Button { tab.go(to: index) } label: {
                            VStack(spacing: 6) {
                                PageThumbnail(page: tab.pdf.page(at: index), width: 116)
                                    .id(tab.revision)
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 4)
                                            .strokeBorder(current ? Color.accentColor : .clear, lineWidth: 2.5)
                                            .padding(-5)
                                    }
                                Text("\(index + 1)")
                                    .font(.caption.monospacedDigit())
                                    .foregroundStyle(current ? .primary : .secondary)
                            }
                        }
                        .buttonStyle(.plain)
                        .id(index)
                    }
                }
                .padding(18)
                .frame(maxWidth: .infinity)
            }
            .onChange(of: tab.pageIndex) {
                withAnimation { proxy.scrollTo(tab.pageIndex, anchor: .center) }
            }
        }
    }
}

// MARK: - Commentaires

private struct CommentsPanel: View {
    let tab: DocumentTab

    var body: some View {
        let items = tab.annotationItems()
        if items.isEmpty {
            ContentUnavailableView(tr("Aucun commentaire"), systemImage: "text.bubble",
                                   description: Text(tr("Utilisez la barre d’outils flottante pour ajouter une note, surligner ou dessiner.")))
        } else {
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(items) { item in
                        CommentRow(tab: tab, item: item)
                    }
                }
                .padding(12)
            }
        }
    }
}

private struct CommentRow: View {
    let tab: DocumentTab
    let item: AnnotationItem

    var body: some View {
        let annotation = item.annotation
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: item.kind.symbol)
                    .foregroundStyle(Color(nsColor: annotation.color.withAlphaComponent(1)))
                Text(item.kind.label).font(.subheadline.weight(.medium))
                Text("\(tr("Page")) \(item.pageIndex + 1)").font(.subheadline).foregroundStyle(.secondary)
                Spacer()
                IconButton(symbol: "trash", help: tr("Supprimer")) { tab.remove([(annotation, item.page)]) }
            }
            if let marked = item.markedText, !marked.isEmpty {
                Text(marked)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
                    .padding(.leading, 8)
                    .overlay(alignment: .leading) {
                        Capsule().fill(Color(nsColor: annotation.color.withAlphaComponent(1))).frame(width: 2)
                    }
            }
            TextField(annotation.type == "FreeText" ? tr("Texte affiché") : tr("Ajouter un commentaire…"),
                      text: Binding(get: { annotation.contents ?? "" }, set: { tab.setContents($0, of: item) }),
                      axis: .vertical)
                .textFieldStyle(.plain)
                .font(.callout)
            Text([annotation.userName, annotation.modificationDate?.formatted(date: .abbreviated, time: .shortened)]
                    .compactMap { $0 }.joined(separator: " · "))
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color(nsColor: .controlBackgroundColor)))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.primary.opacity(0.08)))
        .contentShape(Rectangle())
        .onTapGesture { tab.go(to: item.pageIndex) }
    }
}

// MARK: - Signets

private struct BookmarksPanel: View {
    let tab: DocumentTab

    var body: some View {
        let items = tab.pdf.outlineRoot.map { OutlineItem.items(of: $0, in: tab.pdf) } ?? []
        if items.isEmpty {
            ContentUnavailableView(tr("Aucun signet"), systemImage: "bookmark",
                                   description: Text(tr("Ce document ne contient pas de table des matières.")))
        } else {
            List(items, children: \.children) { item in
                Text(item.label)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                    .onTapGesture { if let page = item.pageIndex { tab.go(to: page) } }
            }
            .listStyle(.sidebar)
        }
    }
}

// MARK: - Recherche

private struct SearchPanel: View {
    let tab: DocumentTab

    var body: some View {
        if tab.results.isEmpty && tab.isSearching {
            ProgressView(tr("Recherche en cours…"))
        } else if tab.results.isEmpty && !hasText {
            ContentUnavailableView(tr("Aucun texte à rechercher"), systemImage: "doc.viewfinder",
                                   description: Text(tr("Ce PDF semble numérisé : ses pages sont des images, sans texte sélectionnable.")))
        } else if tab.results.isEmpty {
            ContentUnavailableView(tr("Aucun résultat"), systemImage: "magnifyingglass",
                                   description: Text(tr("Saisissez un mot dans le champ de recherche, puis appuyez sur Entrée.")))
        } else {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 2) {
                        Text(tab.results.count == 1 ? tr("1 résultat") : "\(tab.results.count) \(tr("résultats"))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.bottom, 6)
                        ForEach(tab.results.indices, id: \.self) { index in
                            resultRow(index).id(index)
                        }
                    }
                    .padding(10)
                }
                .onChange(of: tab.resultIndex) { proxy.scrollTo(tab.resultIndex, anchor: .center) }
            }
        }
    }

    /// Échantillon des premières pages : suffit à repérer un document numérisé.
    private var hasText: Bool {
        (0..<min(5, tab.pdf.pageCount)).contains { !(tab.pdf.page(at: $0)?.string ?? "").isEmpty }
    }

    private func resultRow(_ index: Int) -> some View {
        let selection = tab.results[index]
        let page = selection.pages.first.map { tab.pdf.index(for: $0) + 1 } ?? 0
        return Button { tab.showResult(index) } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(tr("Page")) \(page)").font(.caption.weight(.medium)).foregroundStyle(.secondary)
                Text(snippet(for: selection)).font(.callout).lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(8)
            .background(RoundedRectangle(cornerRadius: 8).fill(index == tab.resultIndex ? Color.accentColor.opacity(0.15) : .clear))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    /// La ligne entière autour du résultat, avec le terme recherché en gras.
    private func snippet(for selection: PDFSelection) -> AttributedString {
        guard let line = selection.copy() as? PDFSelection else { return AttributedString() }
        line.extendForLineBoundaries()
        var text = AttributedString(line.string?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "")
        if let range = text.range(of: tab.searchText, options: [.caseInsensitive, .diacriticInsensitive]) {
            text[range].font = .callout.bold()
        }
        return text
    }
}
