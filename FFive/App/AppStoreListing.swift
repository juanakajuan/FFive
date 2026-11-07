import Foundation

/// FFive's App Store listing.
enum AppStoreListing {
    /// The numeric Apple ID from App Store Connect (App Information > Apple ID).
    /// PLACEHOLDER: the project does not record it yet. Replace it before release.
    static let appID = "0000000000"

    static let writeReviewURL = URL(string: "https://apps.apple.com/app/id\(appID)?action=write-review")!
}
