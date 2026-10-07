import SwiftUI

/// Konfetti-eksplosion, når en hel opgave bliver færdig.
struct ConfettiView: View {
    var trigger: Int

    @State private var pieces: [ConfettiPiece.Model] = []

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(pieces) { piece in
                    ConfettiPiece(model: piece, area: geo.size)
                }
            }
        }
        .allowsHitTesting(false)
        .ignoresSafeArea()
        .onChange(of: trigger) { _, _ in
            burst()
        }
    }

    private func burst() {
        let colors: [Color] = [Theme.accent, Urgency.later.color, Urgency.done.color, Urgency.thisMonth.color, .white]
        pieces = (0..<80).map { _ in
            ConfettiPiece.Model(
                color: colors.randomElement() ?? .pink,
                startX: CGFloat.random(in: 0.4...0.6),
                endX: CGFloat.random(in: -0.1...1.1),
                peak: CGFloat.random(in: 0.05...0.35),
                size: CGFloat.random(in: 6...11),
                spin: Double.random(in: 180...900),
                delay: Double.random(in: 0...0.15),
                duration: Double.random(in: 1.4...2.4)
            )
        }
        let current = trigger
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            if current == trigger { pieces = [] }
        }
    }
}

struct ConfettiPiece: View {
    struct Model: Identifiable {
        let id = UUID()
        let color: Color
        let startX: CGFloat
        let endX: CGFloat
        let peak: CGFloat
        let size: CGFloat
        let spin: Double
        let delay: Double
        let duration: Double
    }

    let model: Model
    let area: CGSize

    /// 0 = start, 1 = toppunkt, 2 = faldet ned.
    @State private var phase = 0

    var body: some View {
        let x: CGFloat = phase == 0 ? model.startX
            : (phase == 1 ? model.startX + (model.endX - model.startX) * 0.4 : model.endX)
        let y: CGFloat = phase == 0 ? 0.55 : (phase == 1 ? model.peak : 1.1)

        RoundedRectangle(cornerRadius: 2)
            .fill(model.color)
            .frame(width: model.size, height: model.size * 1.6)
            .rotationEffect(.degrees(phase == 0 ? 0 : model.spin))
            .rotation3DEffect(.degrees(phase == 2 ? model.spin : 0), axis: (x: 1, y: 0.4, z: 0))
            .position(x: x * area.width, y: y * area.height)
            .opacity(phase == 0 ? 0 : (phase == 1 ? 1 : 0.2))
            .onAppear {
                withAnimation(.easeOut(duration: 0.45).delay(model.delay)) {
                    phase = 1
                } completion: {
                    withAnimation(.easeIn(duration: model.duration)) {
                        phase = 2
                    }
                }
            }
    }
}
