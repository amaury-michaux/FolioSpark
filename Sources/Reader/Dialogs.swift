import AppKit
import UniformTypeIdentifiers

@MainActor
func showAlert(_ title: String, _ message: String) {
    let alert = NSAlert()
    alert.messageText = title
    alert.informativeText = message
    alert.runModal()
}

@MainActor
func pickPDFs(message: String? = nil) -> [URL] {
    let panel = NSOpenPanel()
    panel.allowedContentTypes = [.pdf]
    panel.allowsMultipleSelection = true
    if let message { panel.message = message }
    return panel.runModal() == .OK ? panel.urls : []
}

@MainActor
func pickSaveURL(name: String, type: UTType, directory: URL?) -> URL? {
    let panel = NSSavePanel()
    panel.allowedContentTypes = [type]
    panel.nameFieldStringValue = name
    panel.directoryURL = directory
    return panel.runModal() == .OK ? panel.url : nil
}

/// Demande un mot de passe ; `confirm` ajoute un second champ de vérification.
@MainActor
func askPassword(title: String, message: String, button: String, confirm: Bool = false) -> String? {
    let field = NSSecureTextField(frame: NSRect(x: 0, y: 0, width: 260, height: 24))
    field.placeholderString = tr("Mot de passe")
    let again = NSSecureTextField(frame: NSRect(x: 0, y: 0, width: 260, height: 24))
    again.placeholderString = tr("Confirmer le mot de passe")
    let stack = NSStackView(views: confirm ? [field, again] : [field])
    stack.orientation = .vertical
    stack.spacing = 8
    stack.frame = NSRect(x: 0, y: 0, width: 260, height: confirm ? 56 : 24)

    var info = message
    while true {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = info
        alert.accessoryView = stack
        alert.addButton(withTitle: button)
        alert.addButton(withTitle: tr("Annuler"))
        alert.window.initialFirstResponder = field
        guard alert.runModal() == .alertFirstButtonReturn else { return nil }
        if field.stringValue.isEmpty {
            info = tr("Le mot de passe ne peut pas être vide.")
        } else if confirm && field.stringValue != again.stringValue {
            info = tr("Les mots de passe ne correspondent pas.")
        } else {
            return field.stringValue
        }
    }
}
