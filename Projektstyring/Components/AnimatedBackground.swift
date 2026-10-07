import SwiftUI

/// Rolig baggrund. Den er bevidst statisk: en evigt kørende, sløret animation
/// bag listen kostede billeder pr. sekund under scroll.
struct AnimatedBackground: View {
    var tint: Color = Theme.accent

    var body: some View {
        LinearGradient(
            colors: [tint.opacity(0.12), Theme.background, Theme.background],
            startPoint: .top,
            endPoint: .center
        )
        .background(Theme.background)
        .ignoresSafeArea()
    }
}
