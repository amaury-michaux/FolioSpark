import AppKit
import PDFKit
import UniformTypeIdentifiers

@Observable @MainActor
final class DocumentTab: Identifiable {
    typealias Placed = (annotation: PDFAnnotation, page: PDFPage)

    let id = UUID()
    let pdf: PDFDocument
    var url: URL?
    var isDirty = false
    /// Incrémenté à chaque modification du PDF (non observable en soi) pour rafraîchir les vues.
    var revision = 0

    var mode = Mode.read
    var tool = Tool.select
    var color = NSColor.systemYellow
    var showTools = true
    var panel: SidePanel?
    var pageIndex = 0

    var searchText = ""
    var results: [PDFSelection] = []
    var resultIndex = 0
    var isSearching = false
    var searchFocusRequest = 0
    @ObservationIgnored private var lastQuery = ""

    @ObservationIgnored weak var pdfView: PDFView?

    init(pdf: PDFDocument, url: URL?) {
        self.pdf = pdf
        self.url = url
        observeSearch()
    }

    var title: String { url?.lastPathComponent ?? tr("Sans titre.pdf") }
    private var baseName: String { url?.deletingPathExtension().lastPathComponent ?? tr("Sans titre") }
    private var folder: URL? { url?.deletingLastPathComponent() }
    var pageCount: Int { _ = revision; return pdf.pageCount }

    private func changed() {
        isDirty = true
        revision += 1
    }

    // MARK: Navigation

    func go(to index: Int) {
        guard let page = pdf.page(at: min(max(index, 0), pdf.pageCount - 1)) else { return }
        mode = .read
        pdfView?.go(to: page)
    }

    func zoomIn() { pdfView?.zoomIn(nil) }
    func zoomOut() { pdfView?.zoomOut(nil) }
    func actualSize() { pdfView?.scaleFactor = 1 }
    func fitToWindow() { pdfView?.autoScales = true }

    // MARK: Recherche

    func focusSearch() {
        mode = .read
        searchFocusRequest += 1
    }

    /// Entrée : lance la recherche (en arrière-plan) ; Entrée à nouveau : résultat suivant.
    func search() {
        guard searchText != lastQuery else {
            if !results.isEmpty { showResult((resultIndex + 1) % results.count) }
            return
        }
        lastQuery = searchText
        pdf.cancelFindString()
        results = []
        resultIndex = 0
        pdfView?.highlightedSelections = nil
        guard !searchText.isEmpty else { return }
        isSearching = true
        panel = .search
        pdf.beginFindString(searchText, withOptions: [.caseInsensitive, .diacriticInsensitive])
    }

    private func observeSearch() {
        let center = NotificationCenter.default
        center.addObserver(forName: .PDFDocumentDidFindMatch, object: pdf, queue: .main) { [weak self] note in
            guard let match = note.userInfo?["PDFDocumentFoundSelection"] as? PDFSelection else { return }
            MainActor.assumeIsolated {
                guard let self else { return }
                self.results.append(match)
                if self.results.count == 1 { self.showResult(0) }
            }
        }
        center.addObserver(forName: .PDFDocumentDidEndFind, object: pdf, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, self.isSearching else { return }
                self.isSearching = false
                self.pdfView?.highlightedSelections = self.results.isEmpty ? nil : self.results
                if self.results.isEmpty { NSSound.beep() }
            }
        }
    }

    func showResult(_ index: Int) {
        guard results.indices.contains(index) else { return }
        mode = .read
        resultIndex = index
        pdfView?.setCurrentSelection(results[index], animate: true)
        pdfView?.scrollSelectionToVisible(nil)
    }

    // MARK: Annotations

    func addMarkup(_ type: PDFAnnotationSubtype, for selection: PDFSelection) {
        add(selection.selectionsByLine().flatMap { line in
            line.pages.map { page in (annotation: makeAnnotation(type, bounds: line.bounds(for: page)), page: page) }
        })
    }

    func addNote(at point: CGPoint, on page: PDFPage) {
        add([(makeAnnotation(.text, bounds: CGRect(x: point.x, y: point.y - 24, width: 24, height: 24)), page)])
        panel = .comments
    }

    func addTextBox(at point: CGPoint, on page: PDFPage) {
        let box = makeAnnotation(.freeText, bounds: CGRect(x: point.x, y: point.y - 24, width: 240, height: 24))
        box.contents = tr("Texte")
        box.font = .systemFont(ofSize: 14)
        box.fontColor = .black
        box.color = .clear
        add([(box, page)])
        panel = .comments
    }

    func addInk(_ points: [CGPoint], on page: PDFPage) {
        guard points.count > 1 else { return }
        let path = NSBezierPath(polyline: points, width: 2)
        let bounds = path.bounds.insetBy(dx: -4, dy: -4)
        // Les tracés d'une annotation Ink sont relatifs à l'origine de ses bornes.
        path.transform(using: AffineTransform(translationByX: -bounds.minX, byY: -bounds.minY))
        let ink = makeAnnotation(.ink, bounds: bounds)
        let border = PDFBorder()
        border.lineWidth = 2
        ink.border = border
        ink.add(path)
        add([(ink, page)])
    }

    private func makeAnnotation(_ type: PDFAnnotationSubtype, bounds: CGRect) -> PDFAnnotation {
        let annotation = PDFAnnotation(bounds: bounds, forType: type, withProperties: nil)
        annotation.color = type == .highlight ? color.withAlphaComponent(0.45) : color
        annotation.userName = NSFullUserName()
        annotation.modificationDate = Date()
        return annotation
    }

    func add(_ placed: [Placed]) {
        guard !placed.isEmpty else { return }
        placed.forEach { $0.page.addAnnotation($0.annotation) }
        pdfView?.undoManager?.registerUndo(withTarget: self) { tab in
            MainActor.assumeIsolated { tab.remove(placed) }
        }
        changed()
    }

    func remove(_ placed: [Placed]) {
        placed.forEach { $0.page.removeAnnotation($0.annotation) }
        pdfView?.undoManager?.registerUndo(withTarget: self) { tab in
            MainActor.assumeIsolated { tab.add(placed) }
        }
        changed()
    }

    func setContents(_ text: String, of item: AnnotationItem) {
        item.annotation.contents = text
        pdfView?.annotationsChanged(on: item.page)
        isDirty = true
    }

    func annotationItems() -> [AnnotationItem] {
        _ = revision
        return (0..<pdf.pageCount).flatMap { index -> [AnnotationItem] in
            guard let page = pdf.page(at: index) else { return [] }
            return page.annotations
                .filter { ["Text", "FreeText", "Highlight", "Underline", "StrikeOut", "Ink"].contains($0.type ?? "") }
                .map { AnnotationItem(annotation: $0, page: page, pageIndex: index) }
        }
    }

    // MARK: Pages

    func rotatePage(_ index: Int, by degrees: Int) {
        guard let page = pdf.page(at: index) else { return }
        page.rotation = (page.rotation + degrees + 360) % 360
        pagesChanged()
    }

    func deletePage(_ index: Int) {
        guard pdf.pageCount > 1 else { NSSound.beep(); return }
        pdf.removePage(at: index)
        pagesChanged()
    }

    /// Déplace la page `from` pour qu'elle occupe la position `to`.
    func movePage(from: Int, to: Int) {
        guard from != to, let page = pdf.page(at: from) else { return }
        pdf.removePage(at: from)
        pdf.insert(page, at: min(to, pdf.pageCount))
        pagesChanged()
    }

    func insertPages() {
        let urls = pickPDFs(message: tr("Les pages seront ajoutées à la fin du document."))
        guard !urls.isEmpty else { return }
        urls.forEach(pdf.appendPages(from:))
        pagesChanged()
    }

    private func pagesChanged() {
        changed()
        pdfView?.layoutDocumentView()
    }

    // MARK: Fichier

    @discardableResult
    func save() -> Bool {
        guard let url else { return saveAs() }
        guard write(to: url) else { return false }
        isDirty = false
        return true
    }

    @discardableResult
    func saveAs() -> Bool {
        guard let dest = pickSaveURL(name: title, type: .pdf, directory: folder), write(to: dest) else { return false }
        url = dest
        isDirty = false
        return true
    }

    func compress() {
        guard let dest = pickSaveURL(name: "\(baseName) \(tr("(compressé)")).pdf", type: .pdf, directory: folder),
              write(to: dest, options: [.saveImagesAsJPEGOption: true, .optimizeImagesForScreenOption: true]) else { return }
        let before = url.flatMap { try? $0.resourceValues(forKeys: [.fileSizeKey]).fileSize }
        let after = try? dest.resourceValues(forKeys: [.fileSizeKey]).fileSize
        showAlert(tr("PDF compressé"), "\(formattedSize(before)) → \(formattedSize(after))")
    }

    func protect() {
        guard let password = askPassword(title: LanguageStore.shared.selection == .french ? "Protéger « \(title) »" : "Protect ‘\(title)’",
                                         message: tr("Une copie protégée sera créée. Ce mot de passe sera demandé à son ouverture."),
                                         button: tr("Continuer"), confirm: true),
              let dest = pickSaveURL(name: "\(baseName) \(tr("(protégé)")).pdf", type: .pdf, directory: folder),
              write(to: dest, options: [.userPasswordOption: password, .ownerPasswordOption: password]) else { return }
        NSWorkspace.shared.activateFileViewerSelecting([dest])
    }

    func exportText() {
        guard let dest = pickSaveURL(name: "\(baseName).txt", type: .plainText, directory: folder) else { return }
        do {
            try (pdf.string ?? "").write(to: dest, atomically: true, encoding: .utf8)
            NSWorkspace.shared.activateFileViewerSelecting([dest])
        } catch {
            showAlert(tr("Exportation impossible"), error.localizedDescription)
        }
    }

    func exportImages() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.prompt = tr("Exporter")
        panel.message = tr("Choisissez le dossier où enregistrer une image PNG par page.")
        guard panel.runModal() == .OK, let dir = panel.url else { return }
        for index in 0..<pdf.pageCount {
            guard let page = pdf.page(at: index) else { continue }
            let box = page.bounds(for: .cropBox)
            let size = page.rotation % 180 == 0 ? box.size : CGSize(width: box.height, height: box.width)
            let image = page.thumbnail(of: NSSize(width: size.width * 2, height: size.height * 2), for: .cropBox)
            guard let tiff = image.tiffRepresentation,
                  let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:]) else { continue }
            try? png.write(to: dir.appendingPathComponent("\(baseName)-\(index + 1).png"))
        }
        NSWorkspace.shared.activateFileViewerSelecting([dir])
    }

    func printDocument() {
        guard let operation = pdf.printOperation(for: .shared, scalingMode: .pageScaleToFit, autoRotate: true) else { return }
        if let window = pdfView?.window {
            operation.runModal(for: window, delegate: nil, didRun: nil, contextInfo: nil)
        } else {
            operation.run()
        }
    }

    /// Écrit dans un fichier temporaire puis remplace la destination, pour ne jamais laisser un fichier à moitié écrit.
    private func write(to dest: URL, options: [PDFDocumentWriteOption: Any] = [:]) -> Bool {
        do {
            let dir = try FileManager.default.url(for: .itemReplacementDirectory, in: .userDomainMask,
                                                  appropriateFor: dest, create: true)
            let temp = dir.appendingPathComponent(dest.lastPathComponent)
            guard pdf.write(to: temp, withOptions: options) else { throw CocoaError(.fileWriteUnknown) }
            if FileManager.default.fileExists(atPath: dest.path) {
                _ = try FileManager.default.replaceItemAt(dest, withItemAt: temp)
            } else {
                try FileManager.default.moveItem(at: temp, to: dest)
            }
            return true
        } catch {
            showAlert(LanguageStore.shared.selection == .french ? "Impossible d’enregistrer « \(dest.lastPathComponent) »" : "Could not save ‘\(dest.lastPathComponent)’", error.localizedDescription)
            return false
        }
    }
}
