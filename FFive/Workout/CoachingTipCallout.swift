import FFiveCore
import SwiftUI

extension CoachingTip {
    var text: String {
        switch self {
        case .startingLoad:
            "Pick a weight you expect to lift for the bottom of the range at the target RIR, then log the reps you got."
        case .rest:
            "Rest until you could match that set, usually 2 to 3 minutes. Big lifts may need longer."
        }
    }

    var systemImage: String {
        switch self {
        case .startingLoad: "scalemass"
        case .rest: "timer"
        }
    }

    var article: Learn.Article? {
        let id =
            switch self {
            case .startingLoad: "rir"
            case .rest: "rest"
            }
        return Learn.articles.first { $0.id == id }
    }
}

struct CoachingTipCallout: View {
    let tip: CoachingTip
    let position: Int
    var onLearnMore: (Learn.Article) -> Void
    var onDismiss: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: tip.systemImage).font(.system(size: 15)).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(tip.text).font(Theme.caption).fixedSize(horizontal: false, vertical: true)
                if let article = tip.article {
                    Button("Learn more: \(article.title)") { onLearnMore(article) }
                        .font(Theme.caption.weight(.semibold))
                        .a11y(.tipLearnMore, position)
                }
            }
            Spacer(minLength: 0)
            Button(action: onDismiss) {
                Image(systemName: "xmark").font(.system(size: 12, weight: .semibold))
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Dismiss tip")
            .a11y(.tipDismiss, position)
        }
        .foregroundStyle(Theme.infoText)
        .padding(.leading, 8)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.infoFill, in: RoundedRectangle(cornerRadius: Theme.cornerRadius))
    }
}
