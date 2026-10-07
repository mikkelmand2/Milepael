import SwiftUI

/// Rolig baggrund i Apple Music-stil: en blød, sløret farveglød,
/// der langsomt glider frem og tilbage øverst på skærmen.
struct AnimatedBackground: View {
    var tint: Color = Theme.accent

    @Environment(\.colorScheme) private var colorScheme
    @State private var drift = false

    var body: some View {
        let strength = colorScheme == .dark ? 0.38 : 0.22

        ZStack {
            Theme.background

            Circle()
                .fill(tint)
                .frame(width: 420, height: 420)
                .blur(radius: 120)
                .opacity(strength)
                .offset(x: drift ? 110 : -110, y: -300)

            Circle()
                .fill(Color.purple)
                .frame(width: 300, height: 300)
                .blur(radius: 110)
                .opacity(strength * 0.6)
                .offset(x: drift ? -120 : 120, y: -180)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.easeInOut(duration: 9).repeatForever(autoreverses: true)) {
                drift = true
            }
        }
    }
}
