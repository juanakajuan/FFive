import Foundation

/// Where a template came from.
public enum TemplateSource: String, CaseIterable, Identifiable {
    case builtIn, custom
    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .builtIn: "Built-in"
        case .custom: "Custom"
        }
    }
}

/// The Templates tab's search and filters. A nil filter shows every value.
public struct TemplateFilter: Equatable {
    public var search = ""
    public var daysPerWeek: Int?
    public var emphasis: TemplateEmphasis?
    public var source: TemplateSource?
    public var variant: TemplateVariant?

    public init() {}

    /// Whether the filter lets any template from `source` through, so its section shows at all.
    public func shows(_ source: TemplateSource) -> Bool { self.source == nil || self.source == source }

    /// A custom template has no emphasis or variant, so it drops out while either filter is on.
    public func matches(_ template: ProgramTemplate) -> Bool {
        let query = search.trimmingCharacters(in: .whitespaces)
        return shows(template.isBuiltIn ? .builtIn : .custom)
            && (daysPerWeek == nil || template.days.count == daysPerWeek)
            && (emphasis == nil || template.emphasis == emphasis)
            && (variant == nil || (template.isBuiltIn && template.variant == variant))
            && (query.isEmpty || template.name.localizedCaseInsensitiveContains(query))
    }

    public var label: String {
        let active = [
            daysPerWeek.map { "\($0)/week" }, emphasis?.displayName, source?.displayName, variant?.displayName,
        ]
        .compactMap { $0 }
        return active.isEmpty ? "Filters" : active.joined(separator: " · ")
    }
}
