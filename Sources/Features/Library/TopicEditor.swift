import SwiftUI

struct TopicEditor: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme
    @Environment(\.localization) private var l10n
    let store: TimelineStore
    @State private var title = ""
    @State private var symbol = "leaf"
    @State private var error: String?
    @FocusState private var focused: Bool
    private let symbols = ["leaf", "person.crop.square", "pawprint", "house", "sun.max", "heart", "camera", "sparkles"]

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(l10n.text("storyEditor.namePlaceholder"), text: $title)
                        .focused($focused)
                        .accessibilityIdentifier("topicTitle")
                        .onChange(of: title) { title = String(title.prefix(80)) }
                } header: { Text(l10n.text("storyEditor.nameHeader")) }
                Section(l10n.text("storyEditor.symbolHeader")) {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 16) {
                        ForEach(symbols, id: \.self) { value in
                            Button { symbol = value } label: {
                                Image(systemName: value)
                                    .font(.title2)
                                    .frame(maxWidth: .infinity, minHeight: 52)
                                    .background(symbol == value ? theme.accent.opacity(0.15) : .clear, in: .rect(cornerRadius: 12))
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(l10n.text("storyEditor.symbol.\(value)"))
                            .accessibilityAddTraits(symbol == value ? .isSelected : [])
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background { PaperBackground().ignoresSafeArea() }
            .navigationTitle(l10n.text("library.newStory"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(l10n.text("common.cancel")) { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(l10n.text("storyEditor.create")) {
                        do {
                            try store.createTopic(title: title, symbol: symbol)
                            dismiss()
                        } catch { self.error = l10n.error(error) }
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .accessibilityIdentifier("createTopic")
                }
            }
            .alert(l10n.text("storyEditor.errorTitle"), isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
                Button(l10n.text("common.ok")) { error = nil }
            } message: { Text(error ?? "") }
            .onAppear { focused = true }
        }
    }
}
