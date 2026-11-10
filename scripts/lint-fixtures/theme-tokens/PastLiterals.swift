import SwiftUI

// Literals that drifted apart before #146, copied from main at 9ecbec9.
struct PastLiteralsView: View {
    let name: String

    var body: some View {
        VStack {
            Text(name)
                .font(.system(size: 16, weight: .semibold))
            Text(name).font(.system(size: 10.5))
            Label("Rate first", systemImage: "info.circle")
                .foregroundStyle(.white)
            TextField("Name", text: .constant(name))
                .background(Color.gray, in: RoundedRectangle(cornerRadius: 2))
                .overlay(RoundedRectangle(cornerRadius: 2).stroke(Color.gray, lineWidth: 1))
        }
    }
}
