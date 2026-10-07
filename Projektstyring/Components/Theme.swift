import SwiftUI
import UIKit

/// Appens farver. Mørk tilstand er aldrig helt sort, lys tilstand aldrig helt hvid.
enum Theme {
    /// Dæmpet rosa accent (afledt af 255, 64, 140), bruges sparsomt.
    static let accent = Color(light: 0xC2557F, dark: 0xE0809F)
    static let accentSoft = Color(light: 0xF3E1E8, dark: 0x463A3F)

    /// Baggrund: #2E2E2E i mørk, varm off-white i lys.
    static let background = Color(light: 0xF3F1F4, dark: 0x2E2E2E)
    /// Kort og felter ovenpå baggrunden.
    static let surface = Color(light: 0xFBFAFC, dark: 0x3A3A3C)
    /// Lidt kraftigere flade, fx til spor bag bjælker.
    static let surfaceRaised = Color(light: 0xE9E6EC, dark: 0x48484A)
}

extension Color {
    init(hex: UInt32) {
        self.init(uiColor: UIColor(hex: hex))
    }

    /// Farve der skifter automatisk mellem lys og mørk tilstand.
    init(light: UInt32, dark: UInt32) {
        self.init(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(hex: dark) : UIColor(hex: light)
        })
    }
}

extension UIColor {
    convenience init(hex: UInt32) {
        self.init(red: CGFloat((hex >> 16) & 0xFF) / 255,
                  green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255,
                  alpha: 1)
    }
}

/// Valg af lys/mørk tilstand i indstillinger.
enum Appearance: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var label: String {
        switch self {
        case .system: return "Automatisk"
        case .light: return "Lys"
        case .dark: return "Mørk"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

/// Nøgler til indstillinger, så de staves ens overalt.
enum SettingsKey {
    static let appearance = "appearance"
    static let showTagsOnCards = "showTagsOnCards"
    static let showNotesOnCards = "showNotesOnCards"
    static let remindersEnabled = "remindersEnabled"
    static let reminderHour = "reminderHour"
}

extension View {
    /// Giver lister og formularer appens baggrund i stedet for systemets sorte/hvide.
    func themedListBackground() -> some View {
        self
            .scrollContentBackground(.hidden)
            .background(Theme.background)
    }

    /// Rækker i en formular får appens kortfarve.
    func themedRow() -> some View {
        listRowBackground(Theme.surface)
    }
}
