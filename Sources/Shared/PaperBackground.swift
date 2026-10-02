import SwiftUI

struct PaperBackground: View {
    var isPhotoPaper = false
    @Environment(\.theme) private var theme
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        (isPhotoPaper ? theme.paper : theme.background)
            .overlay {
                if theme == .clay || theme == .graphite {
                    Image("PaperTexture")
                        .resizable(resizingMode: .tile)
                        .saturation(theme == .graphite ? 0 : 1)
                        .blendMode(.multiply)
                        .opacity(textureOpacity)
                }
            }
            .clipped()
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    private var textureOpacity: Double {
        if theme == .graphite {
            return colorScheme == .dark ? 0.10 : (isPhotoPaper ? 0.06 : 0.10)
        }
        return colorScheme == .dark ? 0.12 : (isPhotoPaper ? 0.35 : 0.4)
    }
}
