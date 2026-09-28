import AppKit
import PDFKit
import SwiftUI

struct PDFKitView: NSViewRepresentable {
    let tab: DocumentTab

    func makeNSView(context: Context) -> ReaderPDFView {
        let view = ReaderPDFView(tab: tab)
        tab.pdfView = view
        return view
    }

    func updateNSView(_ nsView: ReaderPDFView, context: Context) {}
}

/// PDFView qui applique l'outil actif de l'onglet (surlignage, notes, dessin…).
final class ReaderPDFView: PDFView {
    private weak var tab: DocumentTab?
    private let overlay = InkOverlay()
    private var inkPage: PDFPage?
    private var inkPoints: [CGPoint] = []

    init(tab: DocumentTab) {
        self.tab = tab
        super.init(frame: .zero)
        document = tab.pdf
        autoScales = true
        displayMode = .singlePageContinuous
        pageShadowsEnabled = true
        backgroundColor = .readerCanvas
        // Les PDF déposés s'ouvrent dans un nouvel onglet (RootView), pas à la place du document.
        unregisterDraggedTypes()
        overlay.frame = bounds
        overlay.autoresizingMask = [.width, .height]
        addSubview(overlay)
        NotificationCenter.default.addObserver(self, selector: #selector(pageDidChange), name: .PDFViewPageChanged, object: self)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) non utilisé") }


    @objc private func pageDidChange() {
        guard let page = currentPage, let document else { return }
        tab?.pageIndex = document.index(for: page)
    }

    override func mouseDown(with event: NSEvent) {
        guard let tab, tab.mode == .read else { return super.mouseDown(with: event) }
        let point = convert(event.locationInWindow, from: nil)
        switch tab.tool {
        case .select, .highlight, .underline, .strikeOut:
            super.mouseDown(with: event)
            applyMarkup()
        case .note, .text:
            guard let page = page(for: point, nearest: false) else { return }
            if tab.tool == .note {
                tab.addNote(at: convert(point, to: page), on: page)
            } else {
                tab.addTextBox(at: convert(point, to: page), on: page)
            }
            tab.tool = .select
        case .draw:
            guard let page = page(for: point, nearest: false) else { return }
            inkPage = page
            inkPoints = [convert(point, to: page)]
            overlay.color = tab.color
            overlay.lineWidth = 2 * scaleFactor
            overlay.points = [point]
        }
    }

    override func mouseDragged(with event: NSEvent) {
        guard let inkPage else { return super.mouseDragged(with: event) }
        let point = convert(event.locationInWindow, from: nil)
        inkPoints.append(convert(point, to: inkPage))
        overlay.points.append(point)
    }

    override func mouseUp(with event: NSEvent) {
        if let inkPage {
            tab?.addInk(inkPoints, on: inkPage)
            self.inkPage = nil
            inkPoints = []
            overlay.points = []
            return
        }
        super.mouseUp(with: event)
        applyMarkup()
    }

    override func mouseMoved(with event: NSEvent) {
        if let tab, tab.mode == .read, [.note, .text, .draw].contains(tab.tool) {
            NSCursor.crosshair.set()
        } else {
            super.mouseMoved(with: event)
        }
    }

    /// PDFView peut suivre la souris dans mouseDown ou dans mouseUp : on applique après les deux,
    /// et vider la sélection empêche un double marquage.
    private func applyMarkup() {
        guard let tab, let type = tab.tool.markup,
              let selection = currentSelection, !(selection.string ?? "").isEmpty else { return }
        tab.addMarkup(type, for: selection)
        clearSelection()
    }
}

/// Aperçu du tracé en cours, dessiné au-dessus des pages.
private final class InkOverlay: NSView {
    var points: [CGPoint] = [] { didSet { needsDisplay = true } }
    var color = NSColor.systemYellow
    var lineWidth: CGFloat = 2

    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    override func draw(_ dirtyRect: NSRect) {
        guard points.count > 1 else { return }
        color.setStroke()
        NSBezierPath(polyline: points, width: lineWidth).stroke()
    }
}
