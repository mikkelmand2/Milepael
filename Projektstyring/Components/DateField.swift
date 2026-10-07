import SwiftUI
import UIKit

/// En dato-række, der folder en kalender ud, når man trykker på den.
/// Kalenderen bygges først, når den åbnes (den er tung at lave), og lukker
/// som standard selv, så snart man vælger en dato.
struct DateField: View {
    let title: String
    @Binding var date: Date

    @AppStorage(SettingsKey.autoCloseCalendar) private var autoClose = true
    @State private var isOpen = false

    var body: some View {
        VStack(spacing: 8) {
            Button {
                // Luk tastaturet, så kalenderen kan ses.
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder),
                                                to: nil, from: nil, for: nil)
                withAnimation(.snappy) { isOpen.toggle() }
            } label: {
                HStack {
                    Text(title)
                        .foregroundStyle(.primary)
                    Spacer()
                    Text(date, format: .dateTime.day().month(.wide).year())
                        .fontWeight(.medium)
                        .foregroundStyle(isOpen ? Theme.accent : .primary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(isOpen ? Theme.accentSoft : Theme.surfaceRaised, in: Capsule())
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isOpen {
                DatePicker(title, selection: $date, displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .labelsHidden()
                    .tint(Theme.accent)
                    .transition(.opacity)
                    .onChange(of: date) { _, _ in
                        if autoClose {
                            withAnimation(.snappy) { isOpen = false }
                        }
                    }
            }
        }
        .sensoryFeedback(.selection, trigger: date)
    }
}
