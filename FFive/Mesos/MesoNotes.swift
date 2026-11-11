import FFiveCore
import SwiftUI

/// The block's notes, newest first. With `onEdit`, the card opens the notes screen to add or delete one.
struct MesoNotesCard: View {
    let meso: Mesocycle
    var onEdit: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Mesocycle Notes").font(Theme.cardTitle).foregroundStyle(Theme.text)
                Spacer()
                if let onEdit {
                    Button(meso.notes.isEmpty ? "Add Note" : "Edit", action: onEdit)
                        .font(Theme.detail.weight(.semibold))
                        .foregroundStyle(Theme.infoText)
                        .a11y(.mesoNotesEdit)
                }
            }
            if meso.notes.isEmpty {
                Text("No notes on this mesocycle yet.")
                    .font(Theme.detail)
                    .foregroundStyle(Theme.secondary)
            } else {
                ForEach(meso.notes.reversed()) { MesoNoteText(note: $0) }
            }
        }
        .surfaceCard()
    }
}

private struct MesoNoteText: View {
    let note: MesoNote

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(note.text)
                .font(Theme.body)
                .foregroundStyle(Theme.text)
                .fixedSize(horizontal: false, vertical: true)
            Text(note.date, format: .dateTime.month(.abbreviated).day())
                .font(Theme.caption)
                .foregroundStyle(Theme.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Adds and deletes the block's notes. It opens from the workout menu and the meso detail screen.
struct MesoNotesScreen: View {
    let meso: Mesocycle

    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var draft = ""
    @FocusState private var focused: Bool

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.gutter) {
                    composer
                    ForEach(Array(meso.notes.reversed().enumerated()), id: \.element.id) { index, note in
                        HStack(alignment: .top, spacing: 12) {
                            MesoNoteText(note: note)
                            Button {
                                store.deleteNote(note, from: meso)
                            } label: {
                                Image(systemName: "trash").foregroundStyle(Theme.danger)
                            }
                            .accessibilityLabel("Delete note")
                            .a11y(.mesoNoteDelete, index + 1)
                        }
                        .surfaceCard()
                    }
                }
                .padding(Theme.gutter)
            }
            .background(Theme.page)
            .navigationTitle("Mesocycle Notes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .a11y(.sheetDone)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .interactiveDismissDisabled(!draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        .onAppear { focused = meso.notes.isEmpty }
    }

    private var composer: some View {
        VStack(alignment: .trailing, spacing: 8) {
            TextField("New note", text: $draft, axis: .vertical)
                .font(Theme.body)
                .foregroundStyle(Theme.text)
                .lineLimit(3...8)
                .focused($focused)
                .onChange(of: draft) {
                    if draft.count > MesoNote.maxLength { draft = String(draft.prefix(MesoNote.maxLength)) }
                }
                .accessibilityLabel("New note")
                .a11y(.mesoNoteText)
                .padding(Theme.rowInset)
                .background(Theme.field, in: RoundedRectangle(cornerRadius: Theme.cornerRadius))
            HStack {
                Text("\(draft.count)/\(MesoNote.maxLength)")
                    .font(Theme.caption.monospacedDigit())
                    .foregroundStyle(Theme.secondary)
                Spacer()
                Button("Add Note") {
                    store.addNote(draft, to: meso)
                    draft = ""
                }
                .font(Theme.detail.weight(.semibold))
                .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .a11y(.mesoNoteAdd)
            }
        }
    }
}
