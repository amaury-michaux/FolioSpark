import SwiftUI

@main
struct ReaderApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var language = LanguageStore.shared

    var body: some Scene {
        Window("FolioSpark", id: "main") {
            RootView()
                .environment(appDelegate.model)
                .environment(\.locale, Locale(identifier: language.selection == .french ? "fr_FR" : "en_US"))
                .frame(minWidth: 960, minHeight: 620)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1320, height: 880)
        .commands { ReaderCommands(model: appDelegate.model) }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let model = AppModel()

    func applicationWillFinishLaunching(_ notification: Notification) {
        // Les onglets sont gérés par l'app, pas par les onglets natifs de NSWindow.
        NSWindow.allowsAutomaticWindowTabbing = false
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        urls.forEach(model.open)
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        model.confirmDiscard(model.tabs.filter(\.isDirty)) ? .terminateNow : .terminateCancel
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}

struct ReaderCommands: Commands {
    let model: AppModel
    @State private var language = LanguageStore.shared

    var body: some Commands {
        CommandMenu(tr("Langue")) {
            ForEach(AppLanguage.allCases, id: \.self) { option in
                Button {
                    language.selection = option
                } label: {
                    if language.selection == option { Label(option.name, systemImage: "checkmark") }
                    else { Text(option.name) }
                }
            }
        }
        CommandGroup(replacing: .newItem) {
            Button(tr("Ouvrir…")) { model.presentOpenPanel() }.keyboardShortcut("o")
            Button(tr("Combiner des fichiers…")) { model.combineFiles() }
            Divider()
            Button(tr("Fermer l’onglet")) { model.closeCurrent() }.keyboardShortcut("w")
        }
        CommandGroup(replacing: .saveItem) {
            Button(tr("Enregistrer")) { model.current?.save() }.keyboardShortcut("s")
            Button(tr("Enregistrer sous…")) { model.current?.saveAs() }.keyboardShortcut("s", modifiers: [.command, .shift])
        }
        CommandGroup(replacing: .printItem) {
            Button(tr("Imprimer…")) { model.current?.printDocument() }.keyboardShortcut("p")
        }
        CommandGroup(replacing: .textEditing) {
            Button(tr("Rechercher…")) { model.current?.focusSearch() }.keyboardShortcut("f")
        }
        CommandGroup(before: .sidebar) {
            Button(tr("Zoom avant")) { model.current?.zoomIn() }.keyboardShortcut("+")
            Button(tr("Zoom arrière")) { model.current?.zoomOut() }.keyboardShortcut("-")
            Button(tr("Taille réelle")) { model.current?.actualSize() }.keyboardShortcut("0")
            Button(tr("Ajuster à la fenêtre")) { model.current?.fitToWindow() }.keyboardShortcut("9")
            Divider()
            Button(tr("Onglet suivant")) { model.selectAdjacent(1) }.keyboardShortcut(.tab, modifiers: .control)
            Button(tr("Onglet précédent")) { model.selectAdjacent(-1) }.keyboardShortcut(.tab, modifiers: [.control, .shift])
            Divider()
        }
    }
}
