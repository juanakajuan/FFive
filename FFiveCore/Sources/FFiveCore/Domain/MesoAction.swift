/// An action a mesocycle's menu offers. The Mesos row and the mesocycle page both list `menu(for:)`, so the two
/// menus stay the same.
public enum MesoAction: CaseIterable, Sendable {
    case summary, rename, end, delete

    public static func menu(for meso: Mesocycle) -> [MesoAction] {
        allCases.filter { $0 != .end || meso.isActive }
    }
}
