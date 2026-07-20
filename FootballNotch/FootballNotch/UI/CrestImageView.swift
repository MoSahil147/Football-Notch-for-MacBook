import SwiftUI

struct CrestImageView: View {
    let team: Team
    @State private var image: NSImage?

    var body: some View {
        Group {
            if let image {
                Image(nsImage: image).resizable()
            } else {
                Text(team.shortName.prefix(3).uppercased())
                    .font(.system(size: 8, weight: .bold))
                    .frame(width: 16, height: 16)
                    .background(Circle().fill(Color.gray.opacity(0.3)))
            }
        }
        .frame(width: 16, height: 16)
        .task {
            guard let url = team.crestURL else { return }
            image = await CrestCache.shared.image(for: url)
        }
    }
}
