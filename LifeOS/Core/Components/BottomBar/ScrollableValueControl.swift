import SwiftUI
import AppKit

struct ScrollableValueControl<Value>: View {
    @Environment(\.theme) private var theme

    let value: Value
    let formatter: (Value) -> String
    let identifier: String
    let minWidth: CGFloat
    let onScroll: (Int) -> Void

    @Binding var hoveredControl: String?
    @Binding var scrollAccumulator: CGFloat

    init(
        value: Value,
        formatter: @escaping (Value) -> String,
        identifier: String,
        minWidth: CGFloat = 80,
        hoveredControl: Binding<String?>,
        scrollAccumulator: Binding<CGFloat>,
        onScroll: @escaping (Int) -> Void
    ) {
        self.value = value
        self.formatter = formatter
        self.identifier = identifier
        self.minWidth = minWidth
        self._hoveredControl = hoveredControl
        self._scrollAccumulator = scrollAccumulator
        self.onScroll = onScroll
    }

    var body: some View {
        Text(formatter(value))
            .font(.system(size: 13))
            .foregroundColor(hoveredControl == identifier ? theme.buttonTextHover : theme.buttonText)
            .frame(minWidth: minWidth)
            .padding(.horizontal, 8)
            .contentShape(Rectangle())
            .onHover { hovering in
                hoveredControl = hovering ? identifier : nil
                if hovering {
                    NSCursor.pointingHand.push()
                } else {
                    NSCursor.pop()
                }
            }
    }

    func handleScrollEvent(_ event: NSEvent) -> Bool {
        guard hoveredControl == identifier else { return false }

        scrollAccumulator += event.deltaY

        if scrollAccumulator > 3 {
            onScroll(1)
            scrollAccumulator = 0
            return true
        } else if scrollAccumulator < -3 {
            onScroll(-1)
            scrollAccumulator = 0
            return true
        }

        return false
    }
}

extension ScrollableValueControl where Value == Date {
    static func month(
        date: Date,
        hoveredControl: Binding<String?>,
        scrollAccumulator: Binding<CGFloat>,
        onAdjust: @escaping (Int) -> Void
    ) -> ScrollableValueControl<Date> {
        ScrollableValueControl(
            value: date,
            formatter: { date in
                let formatter = DateFormatter()
                formatter.dateFormat = "MMMM"
                return formatter.string(from: date)
            },
            identifier: "month",
            minWidth: 90,
            hoveredControl: hoveredControl,
            scrollAccumulator: scrollAccumulator,
            onScroll: onAdjust
        )
    }

    static func day(
        date: Date,
        hoveredControl: Binding<String?>,
        scrollAccumulator: Binding<CGFloat>,
        onAdjust: @escaping (Int) -> Void
    ) -> ScrollableValueControl<Date> {
        ScrollableValueControl(
            value: date,
            formatter: { date in
                let formatter = DateFormatter()
                formatter.dateFormat = "d"
                return formatter.string(from: date)
            },
            identifier: "day",
            minWidth: 30,
            hoveredControl: hoveredControl,
            scrollAccumulator: scrollAccumulator,
            onScroll: onAdjust
        )
    }

    static func year(
        date: Date,
        hoveredControl: Binding<String?>,
        scrollAccumulator: Binding<CGFloat>,
        onAdjust: @escaping (Int) -> Void
    ) -> ScrollableValueControl<Date> {
        ScrollableValueControl(
            value: date,
            formatter: { date in
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy"
                return formatter.string(from: date)
            },
            identifier: "year",
            minWidth: 50,
            hoveredControl: hoveredControl,
            scrollAccumulator: scrollAccumulator,
            onScroll: onAdjust
        )
    }
}
