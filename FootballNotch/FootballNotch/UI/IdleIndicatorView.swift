import SwiftUI

/// Shown when no match is being followed, so the notch has a visible,
/// discoverable affordance instead of vanishing entirely — hovering it
/// (AppState.mouseEntered already transitions from .hidden) opens the match
/// picker in HoverExpandedView.
struct IdleIndicatorView: View {
    var body: some View {
        HStack {
            Text("⚽️")
                .font(.system(size: 13))
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 8)
        .frame(height: 32)
        .background(Color.black)
        .clipShape(Capsule())
    }
}
