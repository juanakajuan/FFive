// The tints #179 found: Add Note in accent, and a ⓘ action icon in plain text color.
struct MesoNotesCard: View {
    var body: some View {
        Button("Add Note", action: onEdit)
            .font(Theme.detail.weight(.semibold))
            .foregroundStyle(Theme.accent)
            .a11y(.mesoNotesEdit)
        Button {
            showingCue.toggle()
        } label: {
            ActionIcon(systemName: showingCue ? "info.circle.fill" : "info.circle")
        }
    }
}
