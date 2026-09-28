import Foundation
import Observation

enum AppLanguage: String, CaseIterable {
    case french = "fr"
    case english = "en"

    var name: String { self == .french ? "Français" : "English" }
}

@Observable @MainActor
final class LanguageStore {
    static let shared = LanguageStore()

    var selection: AppLanguage {
        didSet { UserDefaults.standard.set(selection.rawValue, forKey: "appLanguage") }
    }

    private init() {
        if let saved = UserDefaults.standard.string(forKey: "appLanguage"),
           let language = AppLanguage(rawValue: saved) {
            selection = language
        } else {
            selection = Locale.current.language.languageCode?.identifier == "fr" ? .french : .english
        }
    }
}

@MainActor
func tr(_ french: String) -> String {
    guard LanguageStore.shared.selection == .english else { return french }
    return englishTranslations[french] ?? french
}

private let englishTranslations: [String: String] = [
    "Langue": "Language",
    "Accueil": "Home",
    "Ouvrez un PDF ou reprenez là où vous vous étiez arrêté.": "Open a PDF or pick up where you left off.",
    "Combiner des fichiers…": "Combine files…",
    "Combiner des fichiers": "Combine files",
    "Ouvrir un fichier…": "Open a file…",
    "Ouvrir un fichier (⌘O)": "Open a file (⌘O)",
    "Ouvrir…": "Open…",
    "Ouvrir": "Open",
    "Récents": "Recent",
    "Nom": "Name",
    "Emplacement": "Location",
    "Modifié": "Modified",
    "Taille": "Size",
    "Afficher dans le Finder": "Show in Finder",
    "Retirer de la liste": "Remove from list",
    "Aucun fichier récent": "No recent files",
    "Les PDF que vous ouvrez apparaîtront ici.\nVous pouvez aussi glisser un fichier dans cette fenêtre.": "PDFs you open will appear here.\nYou can also drag a file into this window.",
    "Fermer l’onglet": "Close tab",
    "Fermer l’onglet (⌘W)": "Close tab (⌘W)",
    "Fermer l’onglet (modifications non enregistrées)": "Close tab (unsaved changes)",
    "Enregistrer": "Save",
    "Enregistrer (⌘S)": "Save (⌘S)",
    "Enregistrer sous…": "Save As…",
    "Ne pas enregistrer": "Don't Save",
    "Annuler": "Cancel",
    "Imprimer": "Print",
    "Imprimer…": "Print…",
    "Imprimer (⌘P)": "Print (⌘P)",
    "Rechercher…": "Find…",
    "Rechercher dans le document": "Search this document",
    "Zoom avant": "Zoom In",
    "Zoom arrière": "Zoom Out",
    "Zoom avant (⌘+)": "Zoom In (⌘+)",
    "Zoom arrière (⌘−)": "Zoom Out (⌘−)",
    "Taille réelle": "Actual Size",
    "Ajuster à la fenêtre": "Fit to Window",
    "Onglet suivant": "Next Tab",
    "Onglet précédent": "Previous Tab",
    "Tous les outils": "All tools",
    "Commenter": "Comment",
    "Organiser les pages": "Organize pages",
    "Compresser un PDF": "Compress a PDF",
    "Protéger un PDF": "Protect a PDF",
    "Exporter en texte": "Export as text",
    "Exporter en images": "Export as images",
    "Exporter": "Export",
    "Partager": "Share",
    "Masquer les outils": "Hide tools",
    "Couleur": "Color",
    "Aller à la page": "Go to page",
    "Page précédente": "Previous page",
    "Page suivante": "Next page",
    "Faire pivoter la page": "Rotate page",
    "Insérer depuis un fichier…": "Insert from file…",
    "Déplacer vers la gauche": "Move left",
    "Déplacer vers la droite": "Move right",
    "Déplacer la page vers la gauche": "Move page left",
    "Déplacer la page vers la droite": "Move page right",
    "Pivoter à gauche": "Rotate left",
    "Pivoter à droite": "Rotate right",
    "Supprimer": "Delete",
    "Glissez une page sur une autre pour la déplacer": "Drag a page onto another to move it",
    "Terminer": "Done",
    "Sélectionner": "Select",
    "Ajouter une note": "Add a note",
    "Surligner": "Highlight",
    "Souligner": "Underline",
    "Barrer": "Strike through",
    "Dessiner": "Draw",
    "Zone de texte": "Text box",
    "Pages": "Pages",
    "Page": "Page",
    "Commentaires": "Comments",
    "Signets": "Bookmarks",
    "Résultats de recherche": "Search results",
    "Note": "Note",
    "Surlignage": "Highlight",
    "Soulignement": "Underline",
    "Texte barré": "Strikethrough",
    "Dessin": "Drawing",
    "Fermer le panneau": "Close panel",
    "Aucun commentaire": "No comments",
    "Utilisez la barre d’outils flottante pour ajouter une note, surligner ou dessiner.": "Use the floating toolbar to add a note, highlight, or draw.",
    "Texte affiché": "Displayed text",
    "Ajouter un commentaire…": "Add a comment…",
    "Aucun signet": "No bookmarks",
    "Ce document ne contient pas de table des matières.": "This document has no table of contents.",
    "Recherche en cours…": "Searching…",
    "Aucun texte à rechercher": "No searchable text",
    "Ce PDF semble numérisé : ses pages sont des images, sans texte sélectionnable.": "This PDF appears to be scanned: its pages are images without selectable text.",
    "Aucun résultat": "No results",
    "Saisissez un mot dans le champ de recherche, puis appuyez sur Entrée.": "Enter a word in the search field, then press Return.",
    "1 résultat": "1 result",
    "résultats": "results",
    "sur": "of",
    "Sans titre.pdf": "Untitled.pdf",
    "Sans titre": "Untitled",
    "Texte": "Text",
    "Les pages seront ajoutées à la fin du document.": "Pages will be added to the end of the document.",
    "PDF compressé": "PDF compressed",
    "Une copie protégée sera créée. Ce mot de passe sera demandé à son ouverture.": "A protected copy will be created. This password will be required to open it.",
    "Continuer": "Continue",
    "Exportation impossible": "Export failed",
    "Choisissez le dossier où enregistrer une image PNG par page.": "Choose a folder to save one PNG image per page.",
    "Mot de passe": "Password",
    "Confirmer le mot de passe": "Confirm password",
    "Le mot de passe ne peut pas être vide.": "The password cannot be empty.",
    "Les mots de passe ne correspondent pas.": "Passwords do not match.",
    "Le fichier n’est pas un PDF valide ou il est endommagé.": "The file is not a valid PDF or is damaged.",
    "Choisissez les PDF à combiner.": "Choose PDFs to combine.",
    "Saisissez le mot de passe pour ouvrir ce document.": "Enter the password to open this document.",
    "Déverrouiller": "Unlock",
    "Mot de passe incorrect. Réessayez.": "Incorrect password. Try again.",
    "Vos modifications seront perdues si vous ne les enregistrez pas.": "Your changes will be lost if you don't save them.",
    "(compressé)": "(compressed)",
    "(protégé)": "(protected)"
]
