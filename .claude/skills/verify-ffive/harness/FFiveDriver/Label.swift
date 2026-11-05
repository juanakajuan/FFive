import Foundation

/// Matches a step's `"<label>"` against an element's label, identifier, or placeholder.
func labelPredicate(_ label: String) -> NSPredicate {
    let (comparison, pattern) =
        if label.hasPrefix("~") {
            ("CONTAINS", String(label.dropFirst()))
        } else if label.contains("*") {
            ("LIKE", label)
        } else {
            ("==", label)
        }
    return NSPredicate(
        format: "label \(comparison) %@ OR identifier \(comparison) %@ OR placeholderValue \(comparison) %@", pattern,
        pattern, pattern)
}
