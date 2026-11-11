import Foundation

public func formatDuration(_ interval: TimeInterval) -> String {
    let minutes = max(0, Int(interval) / 60)
    return minutes >= 60 ? "\(minutes / 60)h \(minutes % 60)m" : "\(minutes)m"
}

public func formatWeight(_ weight: Double) -> String {
    weight.formatted(.number.precision(.fractionLength(0...1)))
}

extension FormatStyle where Self == Date.FormatStyle {
    /// The day of a past workout in any history list, such as "Tue, Mar 3, 2026".
    public static var sessionDay: Date.FormatStyle {
        .dateTime.weekday(.abbreviated).month(.abbreviated).day().year()
    }
}
