import FFiveCore
import SwiftUI

struct MuscleIcon: View {
    let muscle: Muscle

    var body: some View {
        let (lit, facing) = muscle.figurePart
        Canvas { context, size in
            context.clip(to: Path(CGRect(origin: .zero, size: size)))
            let crop = lit.crop
            let scale = min(size.width / crop.width, size.height / crop.height)
            context.translateBy(
                x: (size.width - crop.width * scale) / 2 - crop.minX * scale,
                y: (size.height - crop.height * scale) / 2 - crop.minY * scale)
            context.scaleBy(x: scale, y: scale)
            for part in BodyPart.allCases where part.isVisible(from: facing) {
                context.fill(part.path, with: .color(part == lit ? muscle.tint : Theme.figure))
            }
        }
        .frame(width: 18, height: 18)
        .accessibilityHidden(true)
    }
}

enum Facing { case front, back }

enum BodyPart: CaseIterable {
    case head, traps, delts, chest, abs, upperBack, lowerBack, upperArms, forearms, hips, thighs, lowerLegs

    static let box = CGSize(width: 24, height: 32)

    var crop: CGRect {
        switch self {
        case .hips, .thighs, .lowerLegs: CGRect(x: 5, y: 18.4, width: 14, height: 13.6)
        case .forearms: CGRect(x: 2.5, y: 5, width: 19, height: 18.6)
        default: CGRect(x: 2.5, y: 0.2, width: 19, height: 18.6)
        }
    }

    func isVisible(from facing: Facing) -> Bool {
        switch self {
        case .chest, .abs: facing == .front
        case .upperBack, .lowerBack: facing == .back
        default: true
        }
    }

    var path: Path {
        switch self {
        case .head:
            Path(ellipseIn: CGRect(x: 9.6, y: 0.4, width: 4.8, height: 5))
        case .traps:
            Path { p in
                p.move(to: CGPoint(x: 10, y: 5.8))
                p.addLine(to: CGPoint(x: 14, y: 5.8))
                p.addLine(to: CGPoint(x: 16.4, y: 8))
                p.addLine(to: CGPoint(x: 7.6, y: 8))
                p.closeSubpath()
            }
        case .delts:
            Path { p in
                p.addEllipse(in: CGRect(x: 4.4, y: 7.6, width: 3.6, height: 4.2))
                p.addEllipse(in: CGRect(x: 16, y: 7.6, width: 3.6, height: 4.2))
            }
        case .chest: Self.pair(x: 8.3, y: 8.4, width: 3.5, height: 4.6, radius: 1.2)
        case .abs: Path(roundedRect: CGRect(x: 8.8, y: 13.4, width: 6.4, height: 5), cornerRadius: 1.2)
        case .upperBack: Path(roundedRect: CGRect(x: 8.3, y: 8.4, width: 7.4, height: 6.6), cornerRadius: 1.4)
        case .lowerBack: Path(roundedRect: CGRect(x: 8.8, y: 15.4, width: 6.4, height: 3), cornerRadius: 1)
        case .upperArms: Self.pair(x: 4.4, y: 12.2, width: 3, height: 5.2, radius: 1.4, mirroredAt: 16.6)
        case .forearms: Self.pair(x: 3.8, y: 17.8, width: 2.7, height: 5.2, radius: 1.3, mirroredAt: 17.5)
        case .hips: Self.pair(x: 8.4, y: 18.8, width: 3.5, height: 3.6, radius: 1.4)
        case .thighs: Self.pair(x: 8.4, y: 22.8, width: 3.4, height: 5, radius: 1.4)
        case .lowerLegs: Self.pair(x: 8.7, y: 28.2, width: 2.8, height: 3.6, radius: 1.2)
        }
    }

    private static func pair(
        x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat, radius: CGFloat,
        mirroredAt rightX: CGFloat? = nil
    ) -> Path {
        Path { p in
            p.addRoundedRect(
                in: CGRect(x: x, y: y, width: width, height: height), cornerSize: CGSize(width: radius, height: radius))
            p.addRoundedRect(
                in: CGRect(x: rightX ?? box.width - x - width, y: y, width: width, height: height),
                cornerSize: CGSize(width: radius, height: radius))
        }
    }
}

extension Muscle {
    var figurePart: (BodyPart, Facing) {
        switch self {
        case .chest: (.chest, .front)
        case .abs: (.abs, .front)
        case .frontDelts, .sideDelts: (.delts, .front)
        case .rearDelts: (.delts, .back)
        case .biceps: (.upperArms, .front)
        case .triceps: (.upperArms, .back)
        case .forearms: (.forearms, .front)
        case .back: (.upperBack, .back)
        case .traps: (.traps, .back)
        case .quads: (.thighs, .front)
        case .hamstrings: (.thighs, .back)
        case .glutes: (.hips, .back)
        case .calves: (.lowerLegs, .back)
        }
    }
}

#Preview {
    LazyVGrid(columns: Array(repeating: GridItem(.fixed(160)), count: 2)) {
        ForEach(Muscle.allCases) { MuscleTag(muscle: $0) }
    }
    .padding()
    .background(Theme.surface)
}
