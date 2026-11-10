extension View {
    func trainAfterAllDialog(
        _ key: Binding<SessionKey?>, of meso: Mesocycle, store: Store,
        onOpen: @escaping (SessionKey) -> Void
    ) -> some View {
        confirmationDialog(
            "Train this day after all?",
            isPresented: Binding(get: { key.wrappedValue != nil }, set: { if !$0 { key.wrappedValue = nil } }),
            titleVisibility: .visible, presenting: key.wrappedValue
        ) { key in
            Button("Train Day \(key.dayIndex + 1)") {
                store.unskip(key, of: meso)
                onOpen(key)
            }
            .a11y(.dialogTrainDay)
        }
    }
}

extension View {
    func scheduleCard() -> some View {
        padding(Theme.gutter)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.cornerRadius))
    }
}
