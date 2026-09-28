import AppKit
import PDFKit

enum Tool: CaseIterable {
    case select, note, highlight, underline, strikeOut, draw, text

    @MainActor var label: String {
        switch self {
        case .select: tr("Sélectionner")
        case .note: tr("Ajouter une note")
        case .highlight: tr("Surligner")
        case .underline: tr("Souligner")
        case .strikeOut: tr("Barrer")
        case .draw: tr("Dessiner")
        case .text: tr("Zone de texte")
        }
    }

    var symbol: String {
        switch self {
        case .select: "cursorarrow"
        case .note: "text.bubble"
        case .highlight: "highlighter"
        case .underline: "underline"
        case .strikeOut: "strikethrough"
        case .draw: "scribble"
        case .text: "character.textbox"
        }
    }

    var markup: PDFAnnotationSubtype? {
        switch self {
        case .highlight: .highlight
        case .underline: .underline
        case .strikeOut: .strikeOut
        default: nil
        }
    }

    var usesColor: Bool { self != .select && self != .text }
}

enum Mode { case read, organize }

enum SidePanel {
    case pages, comments, bookmarks, search

    @MainActor var title: String {
        switch self {
        case .pages: tr("Pages")
        case .comments: tr("Commentaires")
        case .bookmarks: tr("Signets")
        case .search: tr("Résultats de recherche")
        }
    }

    var symbol: String {
        switch self {
        case .pages: "rectangle.grid.1x2"
        case .comments: "text.bubble"
        case .bookmarks: "bookmark"
        case .search: "magnifyingglass"
        }
    }
}

let markupColors: [NSColor] = [.systemYellow, .systemGreen, .systemBlue, .systemPink, .systemRed]

struct AnnotationItem: Identifiable {
    let annotation: PDFAnnotation
    let page: PDFPage
    let pageIndex: Int
    var id: ObjectIdentifier { ObjectIdentifier(annotation) }

    @MainActor var kind: (label: String, symbol: String) {
        switch annotation.type {
        case "Text": (tr("Note"), "text.bubble")
        case "FreeText": (tr("Zone de texte"), "character.textbox")
        case "Highlight": (tr("Surlignage"), "highlighter")
        case "Underline": (tr("Soulignement"), "underline")
        case "StrikeOut": (tr("Texte barré"), "strikethrough")
        default: (tr("Dessin"), "scribble")
        }
    }

    /// Texte du document couvert par un marquage (surlignage, etc.).
    var markedText: String? {
        guard annotation.type != "Text", annotation.type != "FreeText", annotation.type != "Ink" else { return nil }
        return page.selection(for: annotation.bounds)?.string?.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

struct OutlineItem: Identifiable {
    let id = UUID()
    let label: String
    let pageIndex: Int?
    let children: [OutlineItem]?

    static func items(of node: PDFOutline, in pdf: PDFDocument) -> [OutlineItem] {
        (0..<node.numberOfChildren).compactMap { node.child(at: $0) }.map { child in
            let kids = items(of: child, in: pdf)
            return OutlineItem(label: child.label ?? "",
                               pageIndex: child.destination?.page.map { pdf.index(for: $0) },
                               children: kids.isEmpty ? nil : kids)
        }
    }
}

struct RecentFile: Identifiable {
    let url: URL
    let modified: Date?
    let size: Int?
    var id: URL { url }
    var name: String { url.lastPathComponent }
    var folder: String { (url.deletingLastPathComponent().path as NSString).abbreviatingWithTildeInPath }

    init(url: URL) {
        self.url = url
        let values = try? url.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey])
        modified = values?.contentModificationDate
        size = values?.fileSize
    }
}

func formattedSize(_ bytes: Int?) -> String {
    bytes.map { ByteCountFormatter.string(fromByteCount: Int64($0), countStyle: .file) } ?? "—"
}

extension NSBezierPath {
    convenience init(polyline points: [CGPoint], width: CGFloat) {
        self.init()
        guard let first = points.first else { return }
        move(to: first)
        points.dropFirst().forEach { line(to: $0) }
        lineWidth = width
        lineCapStyle = .round
        lineJoinStyle = .round
    }
}

extension NSColor {
    /// Fond du canevas derrière les pages, comme dans Acrobat.
    static let readerCanvas = NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(white: 0.10, alpha: 1)
            : NSColor(white: 0.925, alpha: 1)
    }
}
