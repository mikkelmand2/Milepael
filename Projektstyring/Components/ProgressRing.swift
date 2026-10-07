import SwiftUI

/// Animeret fremdriftsring, der "fyldes op" med en fjeder-animation.
struct ProgressRing: View {
    var progress: Double
    var color: Color
    var lineWidth: CGFloat = 8

    @State private var shown: Double = 0

    var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.18), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: max(shown, 0.001))
                .stroke(color.gradient, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .shadow(color: color.opacity(0.35), radius: lineWidth / 2)
        }
        .padding(lineWidth / 2)
        .onAppear {
            withAnimation(.spring(response: 0.9, dampingFraction: 0.75).delay(0.1)) {
                shown = progress
            }
        }
        .onChange(of: progress) { _, newValue in
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                shown = newValue
            }
        }
    }
}

/// Vandret animeret bjælke (bruges til "tid gået" vs. "arbejde udført").
struct ProgressBar: View {
    var title: String
    var value: Double
    var color: Color

    @State private var shown: Double = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(title)
                Spacer()
                Text(value, format: .percent.precision(.fractionLength(0)))
                    .monospacedDigit()
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(color.opacity(0.15))
                    Capsule()
                        .fill(color.gradient)
                        .frame(width: max(geo.size.width * shown, 8))
                }
            }
            .frame(height: 8)
        }
        .onAppear {
            withAnimation(.spring(response: 1.0, dampingFraction: 0.8).delay(0.2)) {
                shown = value
            }
        }
        .onChange(of: value) { _, newValue in
            withAnimation(.spring(response: 0.6, dampingFraction: 0.75)) {
                shown = newValue
            }
        }
    }
}

/// Knap der "trykkes ind" med en lille fjeder.
struct PressableButtonStyle: ButtonStyle {
    var scale: CGFloat = 0.97

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}
