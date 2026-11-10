import FFiveCore
import SwiftUI

/// Notes edit in a sheet, not an alert, because an alert's text field kept the old text after it was cleared and retyped.
struct NoteEditor: View {
    let title: String
    /// Names the block day a pinned note follows. Nil hides the pin option.
    let dayName: String?
    let onSave: (String, Bool) -> Void

    private let original: (text: String, pinned: Bool)
    @State private var draft: String
    @State private var pinned: Bool
    @FocusState private var focused: Bool

    init(
        title: String, draft: String, pinned: Bool? = nil, dayName: String? = nil,
        onSave: @escaping (String, Bool) -> Void
    ) {
        self.title = title
        self.dayName = pinned == nil ? nil : dayName
        self.onSave = onSave
        original = (draft, pinned ?? false)
        _draft = State(initialValue: draft)
        _pinned = State(initialValue: pinned ?? false)
    }

    var body: some View {
        DraftSheet(
            title, isDirty: draft != original.text || pinned != original.pinned,
            cancelID: .noteCancel, saveID: .noteSave
        ) {
            onSave(draft, pinned)
        } content: {
            VStack {
                TextField("Note", text: $draft, axis: .vertical)
                    .font(Theme.body)
                    .foregroundStyle(Theme.text)
                    .lineLimit(3...8)
                    .focused($focused)
                    .accessibilityLabel("Note")
                    .a11y(.noteText)
                    .padding(Theme.rowInset)
                    .background(Theme.field, in: RoundedRectangle(cornerRadius: Theme.cornerRadius))
                if let dayName {
                    VStack(alignment: .leading, spacing: 4) {
                        Button {
                            pinned.toggle()
                        } label: {
                            HStack(spacing: 12) {
                                ActionIcon(systemName: pinned ? "pin.fill" : "pin")
                                Text("Pin to \(dayName)")
                                    .font(Theme.body)
                                    .foregroundStyle(Theme.text)
                                Spacer(minLength: 0)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(pinned ? "Unpin from \(dayName)" : "Pin to \(dayName)")
                        .a11y(.notePin)
                        Text("Shows on every later \(dayName) session in this mesocycle until you unpin it.")
                            .font(Theme.detail)
                            .foregroundStyle(Theme.secondary)
                    }
                    .padding(.top, 8)
                }
                Spacer()
            }
            .padding(Theme.gutter)
            .background(Theme.page)
        }
        .onAppear { focused = true }
    }
}
