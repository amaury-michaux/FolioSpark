import SwiftUI

struct HomeView: View {
    @Environment(AppModel.self) private var model
    @State private var selection = Set<URL>()

    var body: some View {
        let files = model.recents.map(RecentFile.init)
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(tr("Accueil"))
                        .font(.system(size: 26, weight: .semibold))
                    Text(tr("Ouvrez un PDF ou reprenez là où vous vous étiez arrêté."))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button(tr("Combiner des fichiers…")) { model.combineFiles() }
                    .buttonStyle(.glass)
                Button(tr("Ouvrir un fichier…")) { model.presentOpenPanel() }
                    .buttonStyle(.glassProminent)
            }
            .controlSize(.large)
            .padding(.horizontal, 32)
            .padding(.top, 28)
            .padding(.bottom, 24)

            Text(tr("Récents"))
                .font(.headline)
                .padding(.horizontal, 32)
                .padding(.bottom, 8)

            Table(files, selection: $selection) {
                TableColumn(tr("Nom")) { file in
                    HStack(spacing: 8) {
                        Image(nsImage: NSWorkspace.shared.icon(forFile: file.url.path))
                            .resizable()
                            .frame(width: 20, height: 20)
                        Text(file.name)
                    }
                }
                TableColumn(tr("Emplacement")) { file in
                    Text(file.folder).foregroundStyle(.secondary).truncationMode(.head)
                }
                TableColumn(tr("Modifié")) { file in
                    Text(file.modified?.formatted(.relative(presentation: .named)) ?? "—").foregroundStyle(.secondary)
                }
                .width(150)
                TableColumn(tr("Taille")) { file in
                    Text(formattedSize(file.size)).foregroundStyle(.secondary).monospacedDigit()
                }
                .width(80)
            }
            .tableStyle(.inset(alternatesRowBackgrounds: false))
            .contextMenu(forSelectionType: URL.self) { urls in
                Button(tr("Ouvrir")) { urls.forEach(model.open) }
                Button(tr("Afficher dans le Finder")) { NSWorkspace.shared.activateFileViewerSelecting(Array(urls)) }
                Divider()
                Button(tr("Retirer de la liste")) { urls.forEach(model.removeRecent) }
            } primaryAction: { urls in
                urls.forEach(model.open)
            }
            .overlay {
                if files.isEmpty {
                    ContentUnavailableView(tr("Aucun fichier récent"), systemImage: "doc.richtext",
                                           description: Text(tr("Les PDF que vous ouvrez apparaîtront ici.\nVous pouvez aussi glisser un fichier dans cette fenêtre.")))
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
    }
}
