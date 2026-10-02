import SwiftUI

struct PhotoView: View {
    let photo: PhotoRecord
    let store: TimelineStore

    var body: some View {
        if let image = store.thumbnail(for: photo) {
            Image(uiImage: image).resizable().scaledToFill()
        } else {
            Rectangle().fill(.quaternary)
                .overlay { Image(systemName: "photo").foregroundStyle(.secondary) }
        }
    }
}
