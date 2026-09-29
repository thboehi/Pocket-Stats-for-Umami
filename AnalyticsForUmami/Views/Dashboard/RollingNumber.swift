import SwiftUI

/// A number whose digits roll like a mechanical counter: each digit is a
/// column of 0–9 clipped to one line and moved with a slight spring, the
/// columns starting one after the other from the right.
///
/// Mirrors the CSS trick `translate: 0 calc(var(--d) * -1lh)` on a strip of
/// digits. Separators, units and signs stay still. On first appearance the
/// digits roll up from 0, so freshly loaded figures read as counting in.
struct RollingNumber: View {
    let text: String
    /// Roll up from zeros when the view appears.
    var rollsIn = true

    @State private var displayed: String?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let shown = displayed ?? (rollsIn ? Self.zeroed(text) : text)
        let characters = Array(shown)
        HStack(spacing: 0) {
            // Identified from the right: units keep their column when the
            // number gets longer or shorter.
            ForEach(Self.columns(characters), id: \.id) { column in
                Group {
                    if let digit = column.character.wholeNumberValue, column.character.isASCII {
                        DigitColumn(digit: digit)
                            .animation(animation(for: column.id), value: digit)
                    } else {
                        Text(String(column.character))
                    }
                }
                .transition(.asymmetric(insertion: .push(from: .bottom), removal: .push(from: .top)).combined(with: .opacity))
            }
        }
        .animation(.smooth(duration: 0.35), value: characters.count)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(text))
        .onAppear { if rollsIn { roll(to: text) } }
        .onChange(of: text) { _, newValue in roll(to: newValue) }
    }

    private func roll(to value: String) {
        // Next run loop: the zeros must be on screen for the roll to show.
        Task { @MainActor in displayed = value }
    }

    /// Slight overshoot, rightmost digit first, like the wheels of a counter.
    private func animation(for columnFromRight: Int) -> Animation {
        reduceMotion
            ? .easeInOut(duration: 0.2)
            : .spring(duration: 0.8, bounce: 0.22).delay(Double(columnFromRight) * 0.045)
    }

    private struct Column {
        let id: Int
        let character: Character
    }

    private static func columns(_ characters: [Character]) -> [Column] {
        characters.enumerated().map { Column(id: characters.count - 1 - $0.offset, character: $0.element) }
    }

    static func zeroed(_ text: String) -> String {
        String(text.map { $0.isASCII && $0.isWholeNumber ? "0" : $0 })
    }
}

/// One wheel: the digits 0 to 9 stacked, clipped to one line and moved up.
private struct DigitColumn: View {
    let digit: Int

    var body: some View {
        // The hidden "0" gives the column the size of one digit in the
        // current font (digits are monospaced).
        Text(verbatim: "0")
            .hidden()
            .overlay(alignment: .top) {
                GeometryReader { proxy in
                    VStack(spacing: 0) {
                        ForEach(0..<10, id: \.self) { value in
                            Text(verbatim: "\(value)")
                                .frame(height: proxy.size.height)
                        }
                    }
                    .frame(width: proxy.size.width)
                    .offset(y: -CGFloat(digit) * proxy.size.height)
                }
            }
            .clipped()
    }
}
