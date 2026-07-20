import SwiftUI

struct CompactPillView: View {
    let match: Match

    private var minuteText: String? {
        if case .live(let minute) = match.status {
            return "\(minute)'"
        }
        return nil
    }

    var body: some View {
        // Team initials sit in the panel's left safe zone, score (+ live
        // minute) in the right safe zone — the camera cutout itself sits in
        // the empty middle (Spacer), so neither chunk gets swallowed by the
        // dead zone.
        HStack(spacing: 4) {
            Text("\(match.homeTeam.shortName) vs \(match.awayTeam.shortName)")
                .font(.system(size: 10, weight: .semibold))
                .lineLimit(1)
            Spacer(minLength: 0)
            if let minuteText {
                Text(minuteText)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.green)
            }
            Text("\(match.homeScore)-\(match.awayScore)")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .monospacedDigit()
        }
        .padding(.horizontal, 10)
        .frame(height: 32)
        .background(Color.black)
        .clipShape(Capsule())
    }
}
