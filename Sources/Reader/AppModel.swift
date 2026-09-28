import AppKit
import PDFKit

@Observable @MainActor
final class AppModel {
    var tabs: [DocumentTab] = []
    /// `nil` = écran d'accueil.
    var selectedID: UUID?
    private(set) var recents: [URL]

    init() {
        recents = (UserDefaults.standard.stringArray(forKey: "recents") ?? [])
            .map { URL(fileURLWithPath: $0) }
            .filter { FileManager.default.fileExists(atPath: $0.path) }
    }

    var current: DocumentTab? { tabs.first { $0.id == selectedID } }

    // MARK: Ouverture

    func open(_ url: URL) {
        if let tab = tabs.first(where: { $0.url == url }) {
            selectedID = tab.id
            return
        }
        guard let pdf = PDFDocument(url: url) else {
            showAlert(LanguageStore.shared.selection == .french ? "Impossible d’ouvrir « \(url.lastPathComponent) »" : "Could not open ‘\(url.lastPathComponent)’",
                      tr("Le fichier n’est pas un PDF valide ou il est endommagé."))
            return
        }
        if pdf.isLocked && !unlock(pdf, name: url.lastPathComponent) { return }
        add(DocumentTab(pdf: pdf, url: url))
        addRecent(url)
    }

    func presentOpenPanel() {
        pickPDFs().forEach(open)
    }

    func combineFiles() {
        let urls = pickPDFs(message: tr("Choisissez les PDF à combiner."))
        let combined = PDFDocument()
        urls.forEach(combined.appendPages(from:))
        guard combined.pageCount > 0 else { return }
        let tab = DocumentTab(pdf: combined, url: nil)
        tab.isDirty = true
        add(tab)
    }

    private func add(_ tab: DocumentTab) {
        tabs.append(tab)
        selectedID = tab.id
    }

    private func unlock(_ pdf: PDFDocument, name: String) -> Bool {
        var message = tr("Saisissez le mot de passe pour ouvrir ce document.")
        while let password = askPassword(title: LanguageStore.shared.selection == .french ? "« \(name) » est protégé" : "‘\(name)’ is protected", message: message, button: tr("Déverrouiller")) {
            if pdf.unlock(withPassword: password) { return true }
            message = tr("Mot de passe incorrect. Réessayez.")
        }
        return false
    }

    // MARK: Onglets

    func close(_ tab: DocumentTab) {
        guard !tab.isDirty || confirmDiscard([tab]), let index = tabs.firstIndex(where: { $0 === tab }) else { return }
        tabs.remove(at: index)
        if selectedID == tab.id {
            selectedID = tabs.isEmpty ? nil : tabs[min(index, tabs.count - 1)].id
        }
    }

    func closeCurrent() {
        if let current { close(current) } else { NSApp.keyWindow?.performClose(nil) }
    }

    func selectAdjacent(_ offset: Int) {
        let order: [UUID?] = [nil] + tabs.map(\.id)
        let index = order.firstIndex(of: selectedID) ?? 0
        selectedID = order[(index + offset + order.count) % order.count]
    }

    /// `true` si les onglets peuvent être fermés (enregistrés ou modifications abandonnées).
    func confirmDiscard(_ dirtyTabs: [DocumentTab]) -> Bool {
        for tab in dirtyTabs {
            selectedID = tab.id
            let alert = NSAlert()
            alert.messageText = LanguageStore.shared.selection == .french ? "Enregistrer les modifications de « \(tab.title) » ?" : "Save changes to ‘\(tab.title)’?"
            alert.informativeText = tr("Vos modifications seront perdues si vous ne les enregistrez pas.")
            alert.addButton(withTitle: tr("Enregistrer"))
            alert.addButton(withTitle: tr("Ne pas enregistrer")).hasDestructiveAction = true
            alert.addButton(withTitle: tr("Annuler"))
            switch alert.runModal() {
            case .alertFirstButtonReturn: if !tab.save() { return false }
            case .alertSecondButtonReturn: continue
            default: return false
            }
        }
        return true
    }

    // MARK: Récents

    private func addRecent(_ url: URL) {
        recents.removeAll { $0 == url }
        recents.insert(url, at: 0)
        recents = Array(recents.prefix(30))
        saveRecents()
        NSDocumentController.shared.noteNewRecentDocumentURL(url)
    }

    func removeRecent(_ url: URL) {
        recents.removeAll { $0 == url }
        saveRecents()
    }

    private func saveRecents() {
        UserDefaults.standard.set(recents.map(\.path), forKey: "recents")
    }
}

extension PDFDocument {
    func appendPages(from url: URL) {
        guard let source = PDFDocument(url: url), !source.isLocked else { return }
        for index in 0..<source.pageCount {
            if let page = source.page(at: index)?.copy() as? PDFPage {
                insert(page, at: pageCount)
            }
        }
    }
}
