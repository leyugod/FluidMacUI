import SwiftUI
import AppKit

// MARK: - Calendar Math & Models

/// Represents a single day cell in a 6-week (`42`-cell) monthly calendar grid.
public struct FMCalendarDay: Identifiable, Hashable, Sendable {
    public let id: String
    public let date: Date
    public let dayNumber: Int
    public let isInDisplayedMonth: Bool
    public let isToday: Bool

    public init(
        id: String,
        date: Date,
        dayNumber: Int,
        isInDisplayedMonth: Bool,
        isToday: Bool
    ) {
        self.id = id
        self.date = date
        self.dayNumber = dayNumber
        self.isInDisplayedMonth = isInDisplayedMonth
        self.isToday = isToday
    }
}

/// Pure calendar calculation helpers for `FMCalendarView`, `FMDatePicker`, and `FMDateRangePicker`.
public enum FMCalendarMath {
    /// Returns the first moment of the first day of the month containing `date`.
    public static func startOfMonth(for date: Date, calendar: Calendar = .current) -> Date {
        let comps = calendar.dateComponents([.year, .month], from: date)
        return calendar.date(from: DateComponents(year: comps.year, month: comps.month, day: 1)) ?? calendar.startOfDay(for: date)
    }

    /// Shifts the month of `date` by `offset` months and returns the start of that resulting month.
    public static func shiftMonth(_ date: Date, by offset: Int, calendar: Calendar = .current) -> Date {
        let base = startOfMonth(for: date, calendar: calendar)
        return calendar.date(byAdding: .month, value: offset, to: base) ?? base
    }

    /// Returns the start of the specified calendar `month` (`1...12`) and `year`.
    public static func startOfMonth(year: Int, month: Int, calendar: Calendar = .current) -> Date {
        let clampedMonth = min(max(month, 1), 12)
        return calendar.date(from: DateComponents(year: year, month: clampedMonth, day: 1)) ?? Date()
    }

    /// Returns 7 localized very-short weekday symbols rotated so index `0` matches `calendar.firstWeekday`.
    public static func weekdaySymbols(calendar: Calendar = .current) -> [String] {
        let raw = calendar.veryShortStandaloneWeekdaySymbols.isEmpty
            ? calendar.shortWeekdaySymbols
            : calendar.veryShortStandaloneWeekdaySymbols
        guard raw.count == 7 else { return raw }
        let startIndex = max(0, min(calendar.firstWeekday - 1, 6))
        return Array(raw[startIndex...]) + Array(raw[..<startIndex])
    }

    /// Generates a fixed 42-day (6 weeks × 7 days) calendar grid for the month containing `monthDate`.
    public static func monthGrid(
        for monthDate: Date,
        referenceToday: Date = Date(),
        calendar: Calendar = .current
    ) -> [FMCalendarDay] {
        let monthStart = startOfMonth(for: monthDate, calendar: calendar)
        let targetComps = calendar.dateComponents([.year, .month], from: monthStart)
        let weekday = calendar.component(.weekday, from: monthStart)
        let leadingDays = (weekday - calendar.firstWeekday + 7) % 7
        let gridStart = calendar.date(byAdding: .day, value: -leadingDays, to: monthStart) ?? monthStart

        return (0..<42).compactMap { offset in
            guard let dayDate = calendar.date(byAdding: .day, value: offset, to: gridStart) else {
                return nil
            }
            let comps = calendar.dateComponents([.year, .month, .day], from: dayDate)
            let year = comps.year ?? 0
            let month = comps.month ?? 0
            let day = comps.day ?? 1
            let isInMonth = (year == targetComps.year && month == targetComps.month)
            let isToday = calendar.isDate(dayDate, inSameDayAs: referenceToday)
            return FMCalendarDay(
                id: String(format: "%04d-%02d-%02d", year, month, day),
                date: dayDate,
                dayNumber: day,
                isInDisplayedMonth: isInMonth,
                isToday: isToday
            )
        }
    }

    /// Clamps `date` into `range` when `range` is non-nil.
    public static func clamp(_ date: Date, to range: ClosedRange<Date>?) -> Date {
        guard let range else { return date }
        return min(max(date, range.lowerBound), range.upperBound)
    }

    /// Returns `true` if the calendar day of `day` falls within the day-granular bounds of `range`.
    public static func isDaySelectable(
        _ day: Date,
        in range: ClosedRange<Date>?,
        calendar: Calendar = .current
    ) -> Bool {
        guard let range else { return true }
        let d = calendar.startOfDay(for: day)
        let lower = calendar.startOfDay(for: range.lowerBound)
        let upper = calendar.startOfDay(for: range.upperBound)
        return d >= lower && d <= upper
    }

    /// Normalizes two arbitrary dates into an ordered `ClosedRange<Date>`.
    public static func normalizedRange(_ first: Date, _ second: Date) -> ClosedRange<Date> {
        first <= second ? first...second : second...first
    }

    /// Returns `true` when `day` falls inclusively between the start and end calendar days of `range`.
    public static func isDay(
        _ day: Date,
        within range: ClosedRange<Date>,
        calendar: Calendar = .current
    ) -> Bool {
        let d = calendar.startOfDay(for: day)
        let lower = calendar.startOfDay(for: range.lowerBound)
        let upper = calendar.startOfDay(for: range.upperBound)
        return d >= lower && d <= upper
    }

    /// Combines the year/month/day of `day` with the hour/minute/second of `source`.
    public static func mergingDay(
        _ day: Date,
        preservingTimeFrom source: Date,
        calendar: Calendar = .current
    ) -> Date {
        let dayComps = calendar.dateComponents([.year, .month, .day], from: day)
        let timeComps = calendar.dateComponents([.hour, .minute, .second], from: source)
        var merged = DateComponents()
        merged.year = dayComps.year
        merged.month = dayComps.month
        merged.day = dayComps.day
        merged.hour = timeComps.hour
        merged.minute = timeComps.minute
        merged.second = timeComps.second
        return calendar.date(from: merged) ?? day
    }

    /// Returns a new `Date` keeping the calendar day of `date` with wrapped `hour` (`0...23`) and `minute` (`0...59`).
    public static func updatingTime(
        of date: Date,
        hour: Int,
        minute: Int,
        calendar: Calendar = .current
    ) -> Date {
        let wrappedHour = ((hour % 24) + 24) % 24
        let wrappedMinute = ((minute % 60) + 60) % 60
        let dayComps = calendar.dateComponents([.year, .month, .day], from: date)
        var comps = DateComponents()
        comps.year = dayComps.year
        comps.month = dayComps.month
        comps.day = dayComps.day
        comps.hour = wrappedHour
        comps.minute = wrappedMinute
        comps.second = 0
        return calendar.date(from: comps) ?? date
    }
}

// MARK: - Pure SwiftUI Calendar & Time Components

/// Standalone pure-SwiftUI iOS/macOS-26-style monthly calendar and digital time picker.
public struct FMCalendarView: View {
    @Environment(\.fmTheme) private var theme
    @Environment(\.fmDensity) private var density
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.controlActiveState) private var activeState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @Binding private var selection: Date
    private let displayedComponents: DatePickerComponents
    private let range: ClosedRange<Date>?
    private let calendar: Calendar

    @State private var displayedMonth: Date
    @State private var isShowingMonthYearPicker = false
    @State private var hoveredDayID: String?
    @State private var activeTimePickerMode: TimeQuickPickerMode?

    private enum TimeQuickPickerMode: Hashable {
        case hour
        case minute
    }

    public init(
        selection: Binding<Date>,
        displayedComponents: DatePickerComponents = [.date],
        in range: ClosedRange<Date>? = nil,
        calendar: Calendar = .current
    ) {
        self._selection = selection
        self.displayedComponents = displayedComponents
        self.range = range
        self.calendar = calendar
        self._displayedMonth = State(
            initialValue: FMCalendarMath.startOfMonth(for: selection.wrappedValue, calendar: calendar)
        )
    }

    private var accent: Color {
        FMColor.adaptiveAccent(theme.accentColor, activeState: activeState, scheme: colorScheme)
    }

    private var showsDate: Bool {
        displayedComponents.contains(.date) || !displayedComponents.contains(.hourAndMinute)
    }

    private var showsTime: Bool {
        displayedComponents.contains(.hourAndMinute)
    }

    private var cellSize: CGFloat {
        switch density {
        case .compact: 30
        case .regular: 34
        case .comfortable: 36
        }
    }

    public var body: some View {
        VStack(spacing: FMSpacing.sm) {
            if showsDate {
                calendarHeader

                if isShowingMonthYearPicker {
                    FMMonthYearGrid(
                        displayedMonth: $displayedMonth,
                        calendar: calendar,
                        accent: accent,
                        onSelectMonth: {
                            isShowingMonthYearPicker = false
                        }
                    )
                    .transition(reduceMotion ? .opacity : .opacity.combined(with: .scale(scale: 0.96)))
                } else {
                    weekdayHeaderRow
                    monthDaysGrid
                        .transition(.opacity)
                }
            }

            if showsTime {
                if showsDate {
                    Rectangle()
                        .fill(FMColor.separator(colorScheme))
                        .frame(height: 0.75)
                }

                timeSelectorSection
            }
        }
        .fmAnimation(.micro, value: isShowingMonthYearPicker)
        .fmAnimation(.micro, value: activeTimePickerMode)
        .onChange(of: selection) { _, newValue in
            let monthOfNew = FMCalendarMath.startOfMonth(for: newValue, calendar: calendar)
            if !calendar.isDate(monthOfNew, equalTo: displayedMonth, toGranularity: .month) {
                displayedMonth = monthOfNew
            }
        }
    }

    private var calendarHeader: some View {
        FMCalendarNavigationHeader(
            displayedMonth: $displayedMonth,
            isShowingMonthYearPicker: $isShowingMonthYearPicker,
            calendar: calendar,
            accent: accent,
            onToday: {
                let todayMerged = FMCalendarMath.mergingDay(Date(), preservingTimeFrom: selection, calendar: calendar)
                let clamped = FMCalendarMath.clamp(todayMerged, to: range)
                selection = clamped
                displayedMonth = FMCalendarMath.startOfMonth(for: clamped, calendar: calendar)
                isShowingMonthYearPicker = false
                FMHaptics.perform(.alignment, enabled: theme.hapticsEnabled)
            }
        )
    }

    private var weekdayHeaderRow: some View {
        let symbols = FMCalendarMath.weekdaySymbols(calendar: calendar)
        return LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: 7),
            spacing: 2
        ) {
            ForEach(Array(symbols.enumerated()), id: \.offset) { _, symbol in
                Text(symbol)
                    .font(.fmCaption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 20)
            }
        }
    }

    private var monthDaysGrid: some View {
        let days = FMCalendarMath.monthGrid(for: displayedMonth, calendar: calendar)

        return LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: 7),
            spacing: 4
        ) {
            ForEach(days) { day in
                let isSelected = calendar.isDate(day.date, inSameDayAs: selection)
                let isSelectable = FMCalendarMath.isDaySelectable(day.date, in: range, calendar: calendar)
                let isHovered = hoveredDayID == day.id && isSelectable

                Button {
                    guard isSelectable else { return }
                    let merged = FMCalendarMath.mergingDay(day.date, preservingTimeFrom: selection, calendar: calendar)
                    let clamped = FMCalendarMath.clamp(merged, to: range)
                    selection = clamped
                    if !day.isInDisplayedMonth {
                        displayedMonth = FMCalendarMath.startOfMonth(for: clamped, calendar: calendar)
                    }
                    FMHaptics.perform(.alignment, enabled: theme.hapticsEnabled)
                } label: {
                    ZStack {
                        if isSelected {
                            Circle()
                                .fill(accent)
                                .shadow(color: accent.opacity(0.32), radius: 5, y: 2)
                        } else if isHovered {
                            Circle()
                                .fill(FMColor.controlHoverFill(colorScheme))
                        } else if day.isToday {
                            Circle()
                                .fill(accent.opacity(0.10))
                        }

                        if day.isToday && !isSelected {
                            Circle()
                                .strokeBorder(accent.opacity(0.65), lineWidth: 1.25)
                        }

                        Text("\(day.dayNumber)")
                            .font(.fmNumeric(size: 12.5, weight: isSelected || day.isToday ? .semibold : .medium))
                            .foregroundStyle(dayForegroundColor(day: day, isSelected: isSelected, isSelectable: isSelectable))
                    }
                    .frame(width: cellSize, height: cellSize)
                    .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .focusEffectDisabled()
                .disabled(!isSelectable)
                .accessibilityLabel(day.date.formatted(date: .complete, time: .omitted))
                .accessibilityAddTraits(isSelected ? .isSelected : [])
                .onHover { hovering in
                    hoveredDayID = hovering ? day.id : (hoveredDayID == day.id ? nil : hoveredDayID)
                }
            }
        }
        .fmAnimation(.micro, value: selection)
    }

    private func dayForegroundColor(day: FMCalendarDay, isSelected: Bool, isSelectable: Bool) -> Color {
        if isSelected {
            return .white
        }
        if !isSelectable {
            return .secondary.opacity(0.28)
        }
        if day.isToday {
            return accent
        }
        return day.isInDisplayedMonth ? .primary : .secondary.opacity(0.45)
    }

    private var timeSelectorSection: some View {
        let hour = calendar.component(.hour, from: selection)
        let minute = calendar.component(.minute, from: selection)

        return VStack(spacing: FMSpacing.xs) {
            HStack(spacing: FMSpacing.xs) {
                HStack(spacing: 5) {
                    Image(systemName: "clock")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(accent)
                    Text("Time")
                        .font(.fmHeadline)
                        .foregroundStyle(.primary)
                }

                Spacer(minLength: FMSpacing.xs)

                HStack(spacing: 4) {
                    FMTimeUnitPill(
                        unitLabel: "Hour",
                        value: hour,
                        isExpanded: activeTimePickerMode == .hour,
                        accent: accent,
                        onDecrement: {
                            updateTime(hour: hour - 1, minute: minute)
                        },
                        onIncrement: {
                            updateTime(hour: hour + 1, minute: minute)
                        },
                        onTapValue: {
                            activeTimePickerMode = activeTimePickerMode == .hour ? nil : .hour
                            FMHaptics.perform(.alignment, enabled: theme.hapticsEnabled)
                        }
                    )

                    Text(":")
                        .font(.fmNumeric(size: 13.5, weight: .bold))
                        .foregroundStyle(.secondary)

                    FMTimeUnitPill(
                        unitLabel: "Minute",
                        value: minute,
                        isExpanded: activeTimePickerMode == .minute,
                        accent: accent,
                        onDecrement: {
                            updateTime(hour: hour, minute: minute - 1)
                        },
                        onIncrement: {
                            updateTime(hour: hour, minute: minute + 1)
                        },
                        onTapValue: {
                            activeTimePickerMode = activeTimePickerMode == .minute ? nil : .minute
                            FMHaptics.perform(.alignment, enabled: theme.hapticsEnabled)
                        }
                    )
                }
            }

            if let mode = activeTimePickerMode {
                let items: [Int] = mode == .hour ? Array(0..<24) : stride(from: 0, to: 60, by: 5).map { $0 }
                let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 6)

                LazyVGrid(columns: columns, spacing: 4) {
                    ForEach(items, id: \.self) { item in
                        let isSelected = (mode == .hour ? hour : minute) == item
                        Button {
                            if mode == .hour {
                                updateTime(hour: item, minute: minute)
                            } else {
                                updateTime(hour: hour, minute: item)
                            }
                            activeTimePickerMode = nil
                        } label: {
                            Text(String(format: "%02d", item))
                                .font(.fmNumeric(size: 11.5, weight: isSelected ? .semibold : .medium))
                                .foregroundStyle(isSelected ? .white : .primary)
                                .frame(maxWidth: .infinity)
                                .frame(height: 24)
                                .background(
                                    isSelected ? accent : FMColor.controlFill(colorScheme),
                                    in: RoundedRectangle(cornerRadius: 7, style: .continuous)
                                )
                        }
                        .buttonStyle(.plain)
                        .focusEffectDisabled()
                    }
                }
                .padding(.top, 2)
                .transition(reduceMotion ? .opacity : .opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private func updateTime(hour: Int, minute: Int) {
        let updated = FMCalendarMath.updatingTime(of: selection, hour: hour, minute: minute, calendar: calendar)
        selection = FMCalendarMath.clamp(updated, to: range)
        FMHaptics.perform(.alignment, enabled: theme.hapticsEnabled)
    }
}

/// Clean rounded date & time picker trigger that opens a 100% pure-SwiftUI calendar & digital time popover.
public struct FMDatePicker: View {
    @Environment(\.fmTheme) private var theme
    @Environment(\.fmDensity) private var density
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.controlActiveState) private var activeState
    @Environment(\.isEnabled) private var isEnabled

    @Binding private var date: Date
    private let displayedComponents: DatePickerComponents
    private let range: ClosedRange<Date>?
    private let calendar: Calendar

    @State private var isOpen = false
    @State private var isHovered = false
    @FocusState private var isFocused: Bool

    public init(
        selection: Binding<Date>,
        displayedComponents: DatePickerComponents = [.date],
        in range: ClosedRange<Date>? = nil,
        calendar: Calendar = .current
    ) {
        self._date = selection
        self.displayedComponents = displayedComponents
        self.range = range
        self.calendar = calendar
    }

    private var accent: Color {
        FMColor.adaptiveAccent(theme.accentColor, activeState: activeState, scheme: colorScheme)
    }

    private var isTimeOnly: Bool {
        displayedComponents.contains(.hourAndMinute) && !displayedComponents.contains(.date)
    }

    public var body: some View {
        let radius = FMCornerRadius.control * density.cornerScale
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)

        Button {
            isOpen.toggle()
            FMHaptics.perform(.alignment, enabled: theme.hapticsEnabled)
        } label: {
            HStack(spacing: FMSpacing.xs) {
                Image(systemName: isTimeOnly ? "clock" : "calendar")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(accent)

                Text(formattedDate)
                    .font(.fmControl)
                    .monospacedDigit()
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .rotationEffect(.degrees(isOpen ? 180 : 0))
            }
            .padding(.horizontal, FMSpacing.sm)
            .frame(height: density.controlHeight)
            .background(
                isHovered || isOpen ? FMColor.controlHoverFill(colorScheme) : FMColor.controlFill(colorScheme),
                in: shape
            )
            .overlay {
                shape.strokeBorder(
                    isOpen ? accent.opacity(0.75) : FMColor.hairlineHighlight(colorScheme),
                    lineWidth: isOpen ? 1.25 : 0.75
                )
            }
        }
        .buttonStyle(.plain)
        .opacity(isEnabled ? 1.0 : 0.45)
        .focused($isFocused)
        .focusEffectDisabled()
        .fmFocusRing(isFocused: isFocused, cornerRadius: FMCornerRadius.control)
        .onHover { isHovered = $0 }
        .fmAnimation(.micro, value: isOpen)
        .fmAnimation(.micro, value: isHovered)
        .popover(isPresented: $isOpen, arrowEdge: .bottom) {
            FMCalendarView(
                selection: $date,
                displayedComponents: displayedComponents,
                in: range,
                calendar: calendar
            )
            .padding(FMSpacing.md)
            .frame(width: isTimeOnly ? 268 : 294)
        }
    }

    private var formattedDate: String {
        if displayedComponents.contains(.hourAndMinute) && displayedComponents.contains(.date) {
            return date.formatted(date: .abbreviated, time: .shortened)
        } else if displayedComponents.contains(.hourAndMinute) {
            return date.formatted(date: .omitted, time: .shortened)
        }
        return date.formatted(date: .abbreviated, time: .omitted)
    }
}

/// Pure-SwiftUI date range picker with continuous selection span highlight, hover preview, and quick presets.
public struct FMDateRangePicker: View {
    @Environment(\.fmTheme) private var theme
    @Environment(\.fmDensity) private var density
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.controlActiveState) private var activeState
    @Environment(\.isEnabled) private var isEnabled

    @Binding private var selection: ClosedRange<Date>
    private let bounds: ClosedRange<Date>?
    private let calendar: Calendar

    @State private var isOpen = false
    @State private var isHovered = false
    @State private var displayedMonth: Date
    @State private var isShowingMonthYearPicker = false
    @State private var anchorStart: Date?
    @State private var hoveredDay: Date?
    @FocusState private var isFocused: Bool

    public init(
        selection: Binding<ClosedRange<Date>>,
        in bounds: ClosedRange<Date>? = nil,
        calendar: Calendar = .current
    ) {
        self._selection = selection
        self.bounds = bounds
        self.calendar = calendar
        self._displayedMonth = State(
            initialValue: FMCalendarMath.startOfMonth(for: selection.wrappedValue.lowerBound, calendar: calendar)
        )
    }

    private var accent: Color {
        FMColor.adaptiveAccent(theme.accentColor, activeState: activeState, scheme: colorScheme)
    }

    private var activeVisualRange: ClosedRange<Date> {
        if let anchorStart, let hoveredDay {
            return FMCalendarMath.normalizedRange(anchorStart, hoveredDay)
        }
        return selection
    }

    public var body: some View {
        let radius = FMCornerRadius.control * density.cornerScale
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)

        Button {
            isOpen.toggle()
            if isOpen {
                displayedMonth = FMCalendarMath.startOfMonth(for: selection.lowerBound, calendar: calendar)
                anchorStart = nil
            }
            FMHaptics.perform(.alignment, enabled: theme.hapticsEnabled)
        } label: {
            HStack(spacing: FMSpacing.xs) {
                Image(systemName: "calendar")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(accent)

                Text(formattedRange)
                    .font(.fmControl)
                    .monospacedDigit()
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .rotationEffect(.degrees(isOpen ? 180 : 0))
            }
            .padding(.horizontal, FMSpacing.sm)
            .frame(height: density.controlHeight)
            .background(
                isHovered || isOpen ? FMColor.controlHoverFill(colorScheme) : FMColor.controlFill(colorScheme),
                in: shape
            )
            .overlay {
                shape.strokeBorder(
                    isOpen ? accent.opacity(0.75) : FMColor.hairlineHighlight(colorScheme),
                    lineWidth: isOpen ? 1.25 : 0.75
                )
            }
        }
        .buttonStyle(.plain)
        .opacity(isEnabled ? 1.0 : 0.45)
        .focused($isFocused)
        .focusEffectDisabled()
        .fmFocusRing(isFocused: isFocused, cornerRadius: FMCornerRadius.control)
        .onHover { isHovered = $0 }
        .fmAnimation(.micro, value: isOpen)
        .fmAnimation(.micro, value: isHovered)
        .popover(isPresented: $isOpen, arrowEdge: .bottom) {
            rangePopoverContent
                .padding(FMSpacing.md)
                .frame(width: 304)
        }
    }

    private var rangePopoverContent: some View {
        let range = activeVisualRange
        let days = FMCalendarMath.monthGrid(for: displayedMonth, calendar: calendar)
        let symbols = FMCalendarMath.weekdaySymbols(calendar: calendar)

        return VStack(spacing: FMSpacing.sm) {
            FMCalendarNavigationHeader(
                displayedMonth: $displayedMonth,
                isShowingMonthYearPicker: $isShowingMonthYearPicker,
                calendar: calendar,
                accent: accent,
                onToday: {
                    applyQuickRange(days: 0)
                }
            )

            // Active start -> end readout
            HStack(spacing: FMSpacing.xs) {
                rangeEndpointPill(
                    label: "Start",
                    date: range.lowerBound,
                    isActive: anchorStart == nil
                )

                Image(systemName: "arrow.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)

                rangeEndpointPill(
                    label: "End",
                    date: range.upperBound,
                    isActive: anchorStart != nil
                )
            }

            if isShowingMonthYearPicker {
                FMMonthYearGrid(
                    displayedMonth: $displayedMonth,
                    calendar: calendar,
                    accent: accent,
                    onSelectMonth: {
                        isShowingMonthYearPicker = false
                    }
                )
            } else {
                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7),
                    spacing: 2
                ) {
                    ForEach(Array(symbols.enumerated()), id: \.offset) { _, symbol in
                        Text(symbol)
                            .font(.fmCaption)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 20)
                    }
                }

                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7),
                    spacing: 4
                ) {
                    ForEach(days) { day in
                        let isSelectable = FMCalendarMath.isDaySelectable(day.date, in: bounds, calendar: calendar)
                        let isStart = calendar.isDate(day.date, inSameDayAs: range.lowerBound)
                        let isEnd = calendar.isDate(day.date, inSameDayAs: range.upperBound)
                        let isInRange = FMCalendarMath.isDay(day.date, within: range, calendar: calendar)
                        let isSingleDay = isStart && isEnd
                        let isHoveredDay = hoveredDay.map { calendar.isDate($0, inSameDayAs: day.date) } ?? false

                        Button {
                            guard isSelectable else { return }
                            let clampedDay = FMCalendarMath.clamp(day.date, to: bounds)
                            if let anchor = anchorStart {
                                selection = FMCalendarMath.normalizedRange(anchor, clampedDay)
                                anchorStart = nil
                            } else {
                                anchorStart = clampedDay
                                selection = clampedDay...clampedDay
                            }
                            if !day.isInDisplayedMonth {
                                displayedMonth = FMCalendarMath.startOfMonth(for: clampedDay, calendar: calendar)
                            }
                            FMHaptics.perform(.alignment, enabled: theme.hapticsEnabled)
                        } label: {
                            ZStack {
                                if isInRange && !isSingleDay {
                                    HStack(spacing: 0) {
                                        Rectangle()
                                            .fill(isStart ? Color.clear : accent.opacity(0.15))
                                        Rectangle()
                                            .fill(isEnd ? Color.clear : accent.opacity(0.15))
                                    }
                                    .frame(height: 30)
                                }

                                if isStart || isEnd {
                                    Circle()
                                        .fill(accent)
                                        .frame(width: 32, height: 32)
                                        .shadow(color: accent.opacity(0.28), radius: 4, y: 1.5)
                                } else if isHoveredDay && isSelectable {
                                    Circle()
                                        .fill(FMColor.controlHoverFill(colorScheme))
                                        .frame(width: 32, height: 32)
                                } else if day.isToday {
                                    Circle()
                                        .strokeBorder(accent.opacity(0.6), lineWidth: 1.2)
                                        .frame(width: 32, height: 32)
                                }

                                Text("\(day.dayNumber)")
                                    .font(.fmNumeric(size: 12.5, weight: (isStart || isEnd || day.isToday) ? .semibold : .medium))
                                    .foregroundStyle(
                                        (isStart || isEnd)
                                            ? Color.white
                                            : (!isSelectable
                                                ? Color.secondary.opacity(0.28)
                                                : (day.isToday ? accent : (day.isInDisplayedMonth ? Color.primary : Color.secondary.opacity(0.45))))
                                    )
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 34)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .focusEffectDisabled()
                        .disabled(!isSelectable)
                        .accessibilityLabel(day.date.formatted(date: .complete, time: .omitted))
                        .accessibilityAddTraits((isStart || isEnd) ? .isSelected : [])
                        .onHover { hovering in
                            if hovering && isSelectable {
                                hoveredDay = day.date
                            } else if !hovering, let current = hoveredDay, calendar.isDate(current, inSameDayAs: day.date) {
                                hoveredDay = nil
                            }
                        }
                    }
                }
            }

            Rectangle()
                .fill(FMColor.separator(colorScheme))
                .frame(height: 0.75)

            // Quick range presets
            HStack(spacing: FMSpacing.xs) {
                quickPresetButton("Today") { applyQuickRange(days: 0) }
                quickPresetButton("7 Days") { applyQuickRange(days: 6) }
                quickPresetButton("30 Days") { applyQuickRange(days: 29) }
            }
        }
        .fmAnimation(.micro, value: isShowingMonthYearPicker)
        .fmAnimation(.micro, value: selection)
    }

    private func rangeEndpointPill(label: String, date: Date, isActive: Bool) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(isActive ? accent : .secondary)
            Text(date.formatted(date: .abbreviated, time: .omitted))
                .font(.fmNumeric(size: 12, weight: .medium))
                .foregroundStyle(.primary)
                .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(FMColor.controlFill(colorScheme), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(isActive ? accent.opacity(0.6) : FMColor.hairlineHighlight(colorScheme), lineWidth: isActive ? 1 : 0.5)
        }
    }

    private func quickPresetButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.fmCaption)
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity)
                .frame(height: 26)
                .background(FMColor.controlFill(colorScheme), in: Capsule(style: .continuous))
        }
        .buttonStyle(.plain)
        .focusEffectDisabled()
    }

    private func applyQuickRange(days: Int) {
        let today = calendar.startOfDay(for: Date())
        let end = FMCalendarMath.clamp(today, to: bounds)
        let rawStart = calendar.date(byAdding: .day, value: -days, to: end) ?? end
        let start = FMCalendarMath.clamp(rawStart, to: bounds)
        selection = FMCalendarMath.normalizedRange(start, end)
        displayedMonth = FMCalendarMath.startOfMonth(for: end, calendar: calendar)
        anchorStart = nil
        isShowingMonthYearPicker = false
        FMHaptics.perform(.alignment, enabled: theme.hapticsEnabled)
    }

    private var formattedRange: String {
        let start = selection.lowerBound.formatted(date: .abbreviated, time: .omitted)
        let end = selection.upperBound.formatted(date: .abbreviated, time: .omitted)
        if calendar.isDate(selection.lowerBound, inSameDayAs: selection.upperBound) {
            return start
        }
        return "\(start) – \(end)"
    }
}

// MARK: - Internal Calendar Subviews

private struct FMCalendarNavigationHeader: View {
    @Environment(\.fmTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme

    @Binding var displayedMonth: Date
    @Binding var isShowingMonthYearPicker: Bool
    let calendar: Calendar
    let accent: Color
    let onToday: () -> Void

    @State private var hoveredControl: String?

    var body: some View {
        HStack(spacing: FMSpacing.xs) {
            Button {
                isShowingMonthYearPicker.toggle()
                FMHaptics.perform(.alignment, enabled: theme.hapticsEnabled)
            } label: {
                HStack(spacing: 4) {
                    Text(monthYearTitle)
                        .font(.fmHeadline)
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    Image(systemName: "chevron.right")
                        .font(.system(size: 10.5, weight: .bold))
                        .foregroundStyle(accent)
                        .rotationEffect(.degrees(isShowingMonthYearPicker ? 90 : 0))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(
                    hoveredControl == "title" ? FMColor.controlHoverFill(colorScheme) : .clear,
                    in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                )
            }
            .buttonStyle(.plain)
            .focusEffectDisabled()
            .onHover { hoveredControl = $0 ? "title" : (hoveredControl == "title" ? nil : hoveredControl) }

            Spacer(minLength: 4)

            Button(action: onToday) {
                Text("Today")
                    .font(.fmCaption)
                    .foregroundStyle(accent)
                    .padding(.horizontal, 8)
                    .frame(height: 24)
                    .background(
                        hoveredControl == "today" ? accent.opacity(0.18) : accent.opacity(0.11),
                        in: Capsule(style: .continuous)
                    )
            }
            .buttonStyle(.plain)
            .focusEffectDisabled()
            .onHover { hoveredControl = $0 ? "today" : (hoveredControl == "today" ? nil : hoveredControl) }

            HStack(spacing: 2) {
                navArrowButton(id: "prev", systemImage: "chevron.left", accessibilityLabel: "Previous Month") {
                    displayedMonth = FMCalendarMath.shiftMonth(displayedMonth, by: -1, calendar: calendar)
                    FMHaptics.perform(.alignment, enabled: theme.hapticsEnabled)
                }

                navArrowButton(id: "next", systemImage: "chevron.right", accessibilityLabel: "Next Month") {
                    displayedMonth = FMCalendarMath.shiftMonth(displayedMonth, by: 1, calendar: calendar)
                    FMHaptics.perform(.alignment, enabled: theme.hapticsEnabled)
                }
            }
        }
        .fmAnimation(.micro, value: isShowingMonthYearPicker)
    }

    private func navArrowButton(id: String, systemImage: String, accessibilityLabel: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 11.5, weight: .semibold))
                .foregroundStyle(.primary)
                .frame(width: 26, height: 26)
                .background(
                    hoveredControl == id ? FMColor.controlHoverFill(colorScheme) : FMColor.controlFill(colorScheme),
                    in: Circle()
                )
        }
        .buttonStyle(.plain)
        .focusEffectDisabled()
        .accessibilityLabel(accessibilityLabel)
        .onHover { hoveredControl = $0 ? id : (hoveredControl == id ? nil : hoveredControl) }
    }

    private var monthYearTitle: String {
        let monthIndex = max(0, min(calendar.component(.month, from: displayedMonth) - 1, calendar.monthSymbols.count - 1))
        let monthName = calendar.monthSymbols.isEmpty
            ? displayedMonth.formatted(.dateTime.month(.wide))
            : calendar.monthSymbols[monthIndex]
        let year = calendar.component(.year, from: displayedMonth)
        return "\(monthName) \(year)"
    }
}

private struct FMMonthYearGrid: View {
    @Environment(\.fmTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme

    @Binding var displayedMonth: Date
    let calendar: Calendar
    let accent: Color
    let onSelectMonth: () -> Void

    @State private var selectedYear: Int
    @State private var hoveredMonth: Int?

    init(
        displayedMonth: Binding<Date>,
        calendar: Calendar,
        accent: Color,
        onSelectMonth: @escaping () -> Void
    ) {
        self._displayedMonth = displayedMonth
        self.calendar = calendar
        self.accent = accent
        self.onSelectMonth = onSelectMonth
        self._selectedYear = State(initialValue: calendar.component(.year, from: displayedMonth.wrappedValue))
    }

    var body: some View {
        let activeYear = calendar.component(.year, from: displayedMonth)
        let activeMonth = calendar.component(.month, from: displayedMonth)
        let monthLabels = calendar.shortMonthSymbols

        VStack(spacing: FMSpacing.sm) {
            HStack {
                Button {
                    selectedYear -= 1
                    FMHaptics.perform(.alignment, enabled: theme.hapticsEnabled)
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 11.5, weight: .semibold))
                        .frame(width: 28, height: 26)
                        .background(FMColor.controlFill(colorScheme), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                }
                .buttonStyle(.plain)
                .focusEffectDisabled()
                .accessibilityLabel("Previous Year")

                Spacer()

                Text(String(selectedYear))
                    .font(.fmNumeric(size: 15, weight: .bold))
                    .foregroundStyle(.primary)

                Spacer()

                Button {
                    selectedYear += 1
                    FMHaptics.perform(.alignment, enabled: theme.hapticsEnabled)
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11.5, weight: .semibold))
                        .frame(width: 28, height: 26)
                        .background(FMColor.controlFill(colorScheme), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                }
                .buttonStyle(.plain)
                .focusEffectDisabled()
                .accessibilityLabel("Next Year")
            }

            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 3),
                spacing: 6
            ) {
                ForEach(1...12, id: \.self) { month in
                    let isSelected = (month == activeMonth && selectedYear == activeYear)
                    let isHovered = hoveredMonth == month
                    let title = month - 1 < monthLabels.count ? monthLabels[month - 1] : "\(month)"

                    Button {
                        displayedMonth = FMCalendarMath.startOfMonth(year: selectedYear, month: month, calendar: calendar)
                        FMHaptics.perform(.alignment, enabled: theme.hapticsEnabled)
                        onSelectMonth()
                    } label: {
                        Text(title)
                            .font(.fmControl)
                            .foregroundStyle(isSelected ? .white : .primary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 34)
                            .background(
                                isSelected
                                    ? accent
                                    : (isHovered ? FMColor.controlHoverFill(colorScheme) : FMColor.controlFill(colorScheme)),
                                in: RoundedRectangle(cornerRadius: 9, style: .continuous)
                            )
                    }
                    .buttonStyle(.plain)
                    .focusEffectDisabled()
                    .onHover { hovering in
                        hoveredMonth = hovering ? month : (hoveredMonth == month ? nil : hoveredMonth)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}

private struct FMTimeUnitPill: View {
    @Environment(\.colorScheme) private var colorScheme

    let unitLabel: String
    let value: Int
    let isExpanded: Bool
    let accent: Color
    let onDecrement: () -> Void
    let onIncrement: () -> Void
    let onTapValue: () -> Void

    @State private var hoveredPart: String?

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 8, style: .continuous)

        HStack(spacing: 0) {
            stepButton(id: "minus", symbol: "minus", action: onDecrement)

            Button(action: onTapValue) {
                Text(String(format: "%02d", value))
                    .font(.fmNumeric(size: 13, weight: .semibold))
                    .foregroundStyle(isExpanded ? accent : .primary)
                    .frame(width: 28, height: 26)
                    .background(
                        hoveredPart == "value" ? FMColor.controlHoverFill(colorScheme) : .clear
                    )
            }
            .buttonStyle(.plain)
            .focusEffectDisabled()
            .accessibilityLabel("\(unitLabel) \(String(format: "%02d", value))")
            .onHover { hoveredPart = $0 ? "value" : (hoveredPart == "value" ? nil : hoveredPart) }

            stepButton(id: "plus", symbol: "plus", action: onIncrement)
        }
        .background(FMColor.controlFill(colorScheme), in: shape)
        .overlay {
            shape.strokeBorder(
                isExpanded ? accent.opacity(0.75) : FMColor.hairlineHighlight(colorScheme),
                lineWidth: isExpanded ? 1.1 : 0.6
            )
        }
        .clipShape(shape)
    }

    private func stepButton(id: String, symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 9.5, weight: .bold))
                .foregroundStyle(.secondary)
                .frame(width: 20, height: 26)
                .background(hoveredPart == id ? FMColor.controlHoverFill(colorScheme) : .clear)
        }
        .buttonStyle(.plain)
        .focusEffectDisabled()
        .accessibilityLabel(symbol == "minus" ? "Decrease \(unitLabel)" : "Increase \(unitLabel)")
        .onHover { hoveredPart = $0 ? id : (hoveredPart == id ? nil : hoveredPart) }
    }
}

// MARK: - Color Math & Models

/// sRGB color representation with channels clamped to `0...1`.
public struct FMRGBA: Sendable, Hashable {
    public var red: Double
    public var green: Double
    public var blue: Double
    public var alpha: Double

    public init(red: Double, green: Double, blue: Double, alpha: Double = 1.0) {
        self.red = min(max(red, 0), 1)
        self.green = min(max(green, 0), 1)
        self.blue = min(max(blue, 0), 1)
        self.alpha = min(max(alpha, 0), 1)
    }
}

/// Hue-Saturation-Brightness-Alpha color representation with channels clamped to `0...1`.
public struct FMHSBA: Sendable, Hashable {
    public var hue: Double
    public var saturation: Double
    public var brightness: Double
    public var alpha: Double

    public init(hue: Double, saturation: Double, brightness: Double, alpha: Double = 1.0) {
        self.hue = min(max(hue, 0), 1)
        self.saturation = min(max(saturation, 0), 1)
        self.brightness = min(max(brightness, 0), 1)
        self.alpha = min(max(alpha, 0), 1)
    }
}

/// Pure color-space conversion, hex parsing, formatting, and comparison helpers.
public enum FMColorMath {
    /// Converts `FMHSBA` to sRGB `FMRGBA`.
    public static func hsbToRGB(_ hsba: FMHSBA) -> FMRGBA {
        var h = hsba.hue.truncatingRemainder(dividingBy: 1.0)
        if h < 0 { h += 1.0 }
        let s = min(max(hsba.saturation, 0), 1)
        let v = min(max(hsba.brightness, 0), 1)
        let a = min(max(hsba.alpha, 0), 1)

        if s == 0 {
            return FMRGBA(red: v, green: v, blue: v, alpha: a)
        }

        let scaled = h * 6.0
        let sector = Int(floor(scaled)) % 6
        let f = scaled - floor(scaled)
        let p = v * (1.0 - s)
        let q = v * (1.0 - f * s)
        let t = v * (1.0 - (1.0 - f) * s)

        let (r, g, b): (Double, Double, Double)
        switch sector {
        case 0: (r, g, b) = (v, t, p)
        case 1: (r, g, b) = (q, v, p)
        case 2: (r, g, b) = (p, v, t)
        case 3: (r, g, b) = (p, q, v)
        case 4: (r, g, b) = (t, p, v)
        default: (r, g, b) = (v, p, q)
        }

        return FMRGBA(red: r, green: g, blue: b, alpha: a)
    }

    /// Converts sRGB `FMRGBA` to `FMHSBA`.
    public static func rgbToHSB(_ rgba: FMRGBA) -> FMHSBA {
        let r = min(max(rgba.red, 0), 1)
        let g = min(max(rgba.green, 0), 1)
        let b = min(max(rgba.blue, 0), 1)
        let a = min(max(rgba.alpha, 0), 1)

        let maxC = max(r, max(g, b))
        let minC = min(r, min(g, b))
        let delta = maxC - minC

        let brightness = maxC
        let saturation = maxC > 0 ? (delta / maxC) : 0

        var hue: Double = 0
        if delta > 0 {
            if maxC == r {
                hue = ((g - b) / delta) / 6.0
            } else if maxC == g {
                hue = (((b - r) / delta) + 2.0) / 6.0
            } else {
                hue = (((r - g) / delta) + 4.0) / 6.0
            }
            if hue < 0 { hue += 1.0 }
            if hue >= 1.0 { hue -= 1.0 }
        }

        return FMHSBA(hue: hue, saturation: saturation, brightness: brightness, alpha: a)
    }

    /// Parses `#RGB`, `#RGBA`, `#RRGGBB`, or `#RRGGBBAA` (with or without leading `#`) into `FMRGBA`.
    public static func parseHex(_ hex: String) -> FMRGBA? {
        var cleaned = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.hasPrefix("#") {
            cleaned.removeFirst()
        }
        guard !cleaned.isEmpty, cleaned.allSatisfy(\.isHexDigit) else {
            return nil
        }

        let expanded: String
        switch cleaned.count {
        case 3, 4:
            expanded = cleaned.map { "\($0)\($0)" }.joined()
        case 6, 8:
            expanded = cleaned
        default:
            return nil
        }

        guard let value = UInt64(expanded, radix: 16) else {
            return nil
        }

        if expanded.count == 6 {
            let r = Double((value & 0xFF0000) >> 16) / 255.0
            let g = Double((value & 0x00FF00) >> 8) / 255.0
            let b = Double(value & 0x0000FF) / 255.0
            return FMRGBA(red: r, green: g, blue: b, alpha: 1.0)
        } else {
            let r = Double((value & 0xFF000000) >> 24) / 255.0
            let g = Double((value & 0x00FF0000) >> 16) / 255.0
            let b = Double((value & 0x0000FF00) >> 8) / 255.0
            let a = Double(value & 0x000000FF) / 255.0
            return FMRGBA(red: r, green: g, blue: b, alpha: a)
        }
    }

    /// Formats `FMRGBA` into uppercase `#RRGGBB` (or `#RRGGBBAA` when `includeAlpha` is `true`).
    public static func formatHex(_ rgba: FMRGBA, includeAlpha: Bool = false) -> String {
        let r = Int((min(max(rgba.red, 0), 1) * 255.0).rounded())
        let g = Int((min(max(rgba.green, 0), 1) * 255.0).rounded())
        let b = Int((min(max(rgba.blue, 0), 1) * 255.0).rounded())
        if includeAlpha {
            let a = Int((min(max(rgba.alpha, 0), 1) * 255.0).rounded())
            return String(format: "#%02X%02X%02X%02X", r, g, b, a)
        }
        return String(format: "#%02X%02X%02X", r, g, b)
    }

    /// Extracts sRGB components from a SwiftUI `Color`.
    public static func rgba(from color: Color) -> FMRGBA {
        let nsColor = NSColor(color)
        guard let rgb = nsColor.usingColorSpace(.sRGB) ?? nsColor.usingColorSpace(.deviceRGB) else {
            return FMRGBA(red: 0.04, green: 0.52, blue: 1.0, alpha: 1.0)
        }
        return FMRGBA(
            red: Double(rgb.redComponent),
            green: Double(rgb.greenComponent),
            blue: Double(rgb.blueComponent),
            alpha: Double(rgb.alphaComponent)
        )
    }

    /// Builds a SwiftUI sRGB `Color` from `FMRGBA`.
    public static func color(from rgba: FMRGBA) -> Color {
        Color(.sRGB, red: rgba.red, green: rgba.green, blue: rgba.blue, opacity: rgba.alpha)
    }

    /// Builds a SwiftUI sRGB `Color` from `FMHSBA`.
    public static func color(from hsba: FMHSBA) -> Color {
        color(from: hsbToRGB(hsba))
    }

    /// Compares two SwiftUI colors in sRGB space within `tolerance` per channel.
    public static func colorsApproximatelyEqual(
        _ lhs: Color,
        _ rhs: Color,
        tolerance: Double = 0.015
    ) -> Bool {
        let a = rgba(from: lhs)
        let b = rgba(from: rhs)
        return abs(a.red - b.red) <= tolerance
            && abs(a.green - b.green) <= tolerance
            && abs(a.blue - b.blue) <= tolerance
            && abs(a.alpha - b.alpha) <= tolerance
    }
}

// MARK: - In-Memory Recent Colors Store

@Observable
private final class FMRecentColorStore {
    static let shared = FMRecentColorStore()

    private(set) var colors: [Color] = []

    func record(_ color: Color) {
        let filtered = colors.filter { !FMColorMath.colorsApproximatelyEqual($0, color, tolerance: 0.02) }
        colors = Array(([color] + filtered).prefix(8))
    }
}

// MARK: - Standalone Pure-SwiftUI Color Picker & Swatches

/// Trigger presentation style for standalone `FMColorPicker`.
public enum FMColorPickerTriggerStyle: Sendable, Hashable {
    /// Rounded control pill showing a color swatch dot, live `#RRGGBB` hex readout, and chevron.
    case pill
    /// Exact-diameter circular trigger orb (`size × size`) with rainbow spectrum ring.
    case orb(size: CGFloat = 24)
}

/// Standalone 100% pure-SwiftUI Color Studio picker with 2D S/B canvas, Hue rainbow slider,
/// optional Opacity slider, live editable `#RRGGBB` hex input with copy button, and preset/recent swatches.
public struct FMColorPicker: View {
    public static let defaultPresets: [Color] = [
        FMColor.blue, FMColor.indigo, FMColor.purple, FMColor.pink,
        FMColor.red, FMColor.orange, FMColor.yellow, FMColor.green,
        FMColor.mint, FMColor.teal
    ]

    @Environment(\.fmTheme) private var theme
    @Environment(\.fmDensity) private var density
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.controlActiveState) private var activeState
    @Environment(\.isEnabled) private var isEnabled

    @Binding private var selection: Color
    private let supportsOpacity: Bool
    private let presets: [Color]
    private let style: FMColorPickerTriggerStyle

    @State private var isOpen = false
    @State private var isHovered = false
    @FocusState private var isFocused: Bool

    public init(
        selection: Binding<Color>,
        supportsOpacity: Bool = false,
        presets: [Color] = FMColorPicker.defaultPresets,
        style: FMColorPickerTriggerStyle = .pill
    ) {
        self._selection = selection
        self.supportsOpacity = supportsOpacity
        self.presets = presets
        self.style = style
    }

    private var accent: Color {
        FMColor.adaptiveAccent(theme.accentColor, activeState: activeState, scheme: colorScheme)
    }

    public var body: some View {
        Group {
            switch style {
            case .pill:
                pillTrigger
            case .orb(let size):
                FMCustomColorOrbButton(
                    selection: selection,
                    size: size,
                    showsColorCenter: true,
                    isSelected: false,
                    isOpen: isOpen
                ) {
                    isOpen.toggle()
                    FMHaptics.perform(.alignment, enabled: theme.hapticsEnabled)
                }
                .focused($isFocused)
                .fmFocusRing(isFocused: isFocused, isCapsule: true)
            }
        }
        .opacity(isEnabled ? 1.0 : 0.45)
        .popover(isPresented: $isOpen, arrowEdge: .bottom) {
            FMColorStudioView(
                selection: $selection,
                supportsOpacity: supportsOpacity,
                presets: presets
            )
        }
    }

    private var pillTrigger: some View {
        let radius = FMCornerRadius.control * density.cornerScale
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        let rgba = FMColorMath.rgba(from: selection)
        let hexLabel = FMColorMath.formatHex(rgba, includeAlpha: supportsOpacity && rgba.alpha < 0.999)

        return Button {
            isOpen.toggle()
            FMHaptics.perform(.alignment, enabled: theme.hapticsEnabled)
        } label: {
            HStack(spacing: FMSpacing.xs) {
                ZStack {
                    if supportsOpacity {
                        FMCheckerboardView(squareSize: 4)
                    }
                    selection
                }
                .frame(width: 16, height: 16)
                .clipShape(Circle())
                .overlay {
                    Circle().strokeBorder(Color.white.opacity(colorScheme == .dark ? 0.25 : 0.6), lineWidth: 1)
                }

                Text(hexLabel)
                    .font(.fmMono)
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .rotationEffect(.degrees(isOpen ? 180 : 0))
            }
            .padding(.horizontal, FMSpacing.sm)
            .frame(height: density.controlHeight)
            .background(
                isHovered || isOpen ? FMColor.controlHoverFill(colorScheme) : FMColor.controlFill(colorScheme),
                in: shape
            )
            .overlay {
                shape.strokeBorder(
                    isOpen ? accent.opacity(0.75) : FMColor.hairlineHighlight(colorScheme),
                    lineWidth: isOpen ? 1.25 : 0.75
                )
            }
        }
        .buttonStyle(.plain)
        .focused($isFocused)
        .focusEffectDisabled()
        .fmFocusRing(isFocused: isFocused, cornerRadius: FMCornerRadius.control)
        .onHover { isHovered = $0 }
        .fmAnimation(.micro, value: isOpen)
        .fmAnimation(.micro, value: isHovered)
    }
}

/// Tactile circular color swatch selector with spring ring selection and a pure-SwiftUI Color Studio orb.
public struct FMColorSwatches: View {
    @Environment(\.fmTheme) private var theme
    @Environment(\.isEnabled) private var isEnabled

    @Binding private var selection: Color
    private let colors: [Color]
    private let size: CGFloat
    private let showsCustomPicker: Bool

    @State private var isStudioOpen = false
    @State private var hoveredIndex: Int?

    public init(
        selection: Binding<Color>,
        colors: [Color] = [FMColor.blue, FMColor.indigo, FMColor.purple, FMColor.pink, FMColor.red, FMColor.orange, FMColor.green, FMColor.teal],
        size: CGFloat = 24,
        showsCustomPicker: Bool = true
    ) {
        self._selection = selection
        self.colors = colors
        self.size = size
        self.showsCustomPicker = showsCustomPicker
    }

    private var isCustomColorActive: Bool {
        !colors.contains { FMColorMath.colorsApproximatelyEqual(selection, $0) }
    }

    public var body: some View {
        HStack(spacing: 8) {
            ForEach(Array(colors.enumerated()), id: \.offset) { index, color in
                let isSelected = FMColorMath.colorsApproximatelyEqual(selection, color)
                let isHovered = hoveredIndex == index

                Button {
                    selection = color
                    FMHaptics.perform(.alignment, enabled: theme.hapticsEnabled)
                } label: {
                    Circle()
                        .fill(color)
                        .frame(width: size, height: size)
                        .overlay {
                            if isSelected {
                                Circle()
                                    .strokeBorder(.white, lineWidth: 2)
                                    .padding(2)
                            }
                        }
                        .scaleEffect(isSelected ? 1.12 : (isHovered ? 1.06 : 1.0))
                }
                .buttonStyle(.plain)
                .focusEffectDisabled()
                .accessibilityLabel("Color \(FMColorMath.formatHex(FMColorMath.rgba(from: color)))")
                .accessibilityAddTraits(isSelected ? .isSelected : [])
                .onHover { hovering in
                    hoveredIndex = hovering ? index : (hoveredIndex == index ? nil : hoveredIndex)
                }
            }

            if showsCustomPicker {
                FMCustomColorOrbButton(
                    selection: selection,
                    size: size,
                    showsColorCenter: isCustomColorActive,
                    isSelected: isCustomColorActive,
                    isOpen: isStudioOpen
                ) {
                    isStudioOpen.toggle()
                    FMHaptics.perform(.alignment, enabled: theme.hapticsEnabled)
                }
                .popover(isPresented: $isStudioOpen, arrowEdge: .bottom) {
                    FMColorStudioView(
                        selection: $selection,
                        supportsOpacity: false,
                        presets: colors
                    )
                }
            }
        }
        .opacity(isEnabled ? 1.0 : 0.45)
        .fmAnimation(.micro, value: FMColorMath.rgba(from: selection))
        .fmAnimation(.micro, value: hoveredIndex)
    }
}

// MARK: - Internal Pure-SwiftUI Color Studio Subviews

private struct FMCustomColorOrbButton: View {
    @Environment(\.colorScheme) private var colorScheme

    let selection: Color
    let size: CGFloat
    let showsColorCenter: Bool
    let isSelected: Bool
    let isOpen: Bool
    let action: () -> Void

    @State private var isHovered = false

    private static let rainbowColors: [Color] = [
        Color(hue: 0.00, saturation: 0.92, brightness: 1.0),
        Color(hue: 0.16, saturation: 0.92, brightness: 1.0),
        Color(hue: 0.33, saturation: 0.85, brightness: 0.95),
        Color(hue: 0.50, saturation: 0.88, brightness: 0.95),
        Color(hue: 0.66, saturation: 0.90, brightness: 1.0),
        Color(hue: 0.83, saturation: 0.88, brightness: 1.0),
        Color(hue: 1.00, saturation: 0.92, brightness: 1.0)
    ]

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(
                        AngularGradient(
                            colors: Self.rainbowColors,
                            center: .center
                        )
                    )

                if showsColorCenter {
                    Circle()
                        .fill(selection)
                        .padding(max(3, size * 0.20))
                        .overlay {
                            Circle()
                                .strokeBorder(.white, lineWidth: 1.5)
                                .padding(max(3, size * 0.20))
                        }
                } else {
                    Circle()
                        .fill(colorScheme == .dark ? Color(white: 0.14) : .white)
                        .padding(max(4, size * 0.25))
                        .overlay {
                            Image(systemName: "plus")
                                .font(.system(size: max(8, size * 0.36), weight: .bold))
                                .foregroundStyle(.primary.opacity(0.85))
                        }
                }
            }
            .frame(width: size, height: size)
            .clipShape(Circle())
            .overlay {
                Circle()
                    .strokeBorder(
                        isOpen ? Color.white.opacity(0.9) : Color.black.opacity(colorScheme == .dark ? 0.22 : 0.08),
                        lineWidth: isOpen ? 1.5 : 0.75
                    )
            }
            .scaleEffect(isSelected || isOpen ? 1.12 : (isHovered ? 1.06 : 1.0))
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .focusEffectDisabled()
        .accessibilityLabel("Custom Color Picker")
        .frame(width: size, height: size)
        .onHover { isHovered = $0 }
        .fmAnimation(.micro, value: isHovered)
        .fmAnimation(.micro, value: isOpen)
    }
}

private struct FMColorStudioView: View {
    @Environment(\.fmTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme

    @Binding var selection: Color
    let supportsOpacity: Bool
    let presets: [Color]

    @State private var hsba: FMHSBA
    @State private var hexText: String
    @State private var copiedHex = false
    @State private var isDraggingCanvas = false
    @State private var isDraggingHue = false
    @State private var isDraggingAlpha = false
    @FocusState private var isHexFocused: Bool

    private let recentStore = FMRecentColorStore.shared

    init(
        selection: Binding<Color>,
        supportsOpacity: Bool,
        presets: [Color]
    ) {
        self._selection = selection
        self.supportsOpacity = supportsOpacity
        self.presets = presets
        let initialRGB = FMColorMath.rgba(from: selection.wrappedValue)
        let initialHSB = FMColorMath.rgbToHSB(initialRGB)
        self._hsba = State(initialValue: initialHSB)
        self._hexText = State(
            initialValue: FMColorMath.formatHex(initialRGB, includeAlpha: supportsOpacity && initialRGB.alpha < 0.999)
        )
    }

    private var currentRGB: FMRGBA {
        FMColorMath.hsbToRGB(hsba)
    }

    private var opaqueCurrentColor: Color {
        FMColorMath.color(from: FMRGBA(red: currentRGB.red, green: currentRGB.green, blue: currentRGB.blue, alpha: 1.0))
    }

    private var pureHueColor: Color {
        FMColorMath.color(from: FMHSBA(hue: hsba.hue, saturation: 1, brightness: 1, alpha: 1))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: FMSpacing.sm) {
            saturationBrightnessCanvas

            hueSlider

            if supportsOpacity {
                opacitySlider
            }

            hexControlRow

            if !presets.isEmpty || !recentStore.colors.isEmpty {
                Rectangle()
                    .fill(FMColor.separator(colorScheme))
                    .frame(height: 0.75)

                swatchesSection
            }
        }
        .padding(FMSpacing.md)
        .frame(width: 268)
        .onChange(of: selection) { _, newValue in
            syncFromExternalSelection(newValue)
        }
        .onDisappear {
            recentStore.record(selection)
        }
    }

    // MARK: 2D Saturation / Brightness Canvas

    private var saturationBrightnessCanvas: some View {
        let shape = RoundedRectangle(cornerRadius: FMCornerRadius.control, style: .continuous)

        return GeometryReader { proxy in
            let width = max(1, proxy.size.width)
            let height = max(1, proxy.size.height)
            let thumbX = CGFloat(hsba.saturation) * width
            let thumbY = CGFloat(1.0 - hsba.brightness) * height

            ZStack(alignment: .topLeading) {
                ZStack {
                    pureHueColor

                    LinearGradient(
                        colors: [.white, .white.opacity(0)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )

                    LinearGradient(
                        colors: [.black.opacity(0), .black],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }
                .clipShape(shape)
                .overlay {
                    shape.strokeBorder(FMColor.hairlineHighlight(colorScheme), lineWidth: 0.75)
                }

                Circle()
                    .fill(opaqueCurrentColor)
                    .frame(width: isDraggingCanvas ? 20 : 16, height: isDraggingCanvas ? 20 : 16)
                    .overlay {
                        Circle().strokeBorder(.white, lineWidth: 2.5)
                    }
                    .shadow(color: .black.opacity(0.35), radius: 3, y: 1)
                    .position(x: thumbX, y: thumbY)
                    .fmAnimation(.micro, value: isDraggingCanvas)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        isDraggingCanvas = true
                        let s = min(max(Double(gesture.location.x / width), 0), 1)
                        let b = min(max(1.0 - Double(gesture.location.y / height), 0), 1)
                        hsba.saturation = s
                        hsba.brightness = b
                        commitHSBA()
                    }
                    .onEnded { _ in
                        isDraggingCanvas = false
                        recentStore.record(selection)
                    }
            )
        }
        .frame(height: 152)
    }

    // MARK: Hue Rainbow Slider

    private var hueSlider: some View {
        let spectrumColors: [Color] = [
            Color(hue: 0.0, saturation: 1, brightness: 1),
            Color(hue: 1.0 / 6.0, saturation: 1, brightness: 1),
            Color(hue: 2.0 / 6.0, saturation: 1, brightness: 1),
            Color(hue: 3.0 / 6.0, saturation: 1, brightness: 1),
            Color(hue: 4.0 / 6.0, saturation: 1, brightness: 1),
            Color(hue: 5.0 / 6.0, saturation: 1, brightness: 1),
            Color(hue: 1.0, saturation: 1, brightness: 1)
        ]

        return GeometryReader { proxy in
            let width = max(1, proxy.size.width)
            let thumbDiameter: CGFloat = isDraggingHue ? 19 : 16
            let usable = max(1, width - thumbDiameter)
            let offsetX = CGFloat(hsba.hue) * usable

            ZStack(alignment: .leading) {
                Capsule(style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: spectrumColors,
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(height: 12)
                    .overlay {
                        Capsule(style: .continuous)
                            .strokeBorder(FMColor.hairlineHighlight(colorScheme), lineWidth: 0.5)
                    }

                Circle()
                    .fill(pureHueColor)
                    .frame(width: thumbDiameter, height: thumbDiameter)
                    .overlay {
                        Circle().strokeBorder(.white, lineWidth: 2.5)
                    }
                    .shadow(color: .black.opacity(0.28), radius: 3, y: 1)
                    .offset(x: offsetX)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        isDraggingHue = true
                        let h = min(max(Double((gesture.location.x - thumbDiameter / 2) / usable), 0), 1)
                        let hitEdge = (h == 0 || h == 1) && (hsba.hue != h)
                        hsba.hue = h
                        commitHSBA()
                        if hitEdge {
                            FMHaptics.perform(.alignment, enabled: theme.hapticsEnabled)
                        }
                    }
                    .onEnded { _ in
                        isDraggingHue = false
                        recentStore.record(selection)
                    }
            )
        }
        .frame(height: 22)
        .fmAnimation(.micro, value: isDraggingHue)
    }

    // MARK: Opacity Slider

    private var opacitySlider: some View {
        VStack(spacing: 4) {
            HStack {
                Text("Opacity")
                    .font(.fmCaption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(Int((hsba.alpha * 100).rounded()))%")
                    .font(.fmNumeric(size: 11.5, weight: .semibold))
                    .foregroundStyle(.secondary)
            }

            GeometryReader { proxy in
                let width = max(1, proxy.size.width)
                let thumbDiameter: CGFloat = isDraggingAlpha ? 19 : 16
                let usable = max(1, width - thumbDiameter)
                let offsetX = CGFloat(hsba.alpha) * usable

                ZStack(alignment: .leading) {
                    ZStack {
                        FMCheckerboardView(squareSize: 4)
                        LinearGradient(
                            colors: [opaqueCurrentColor.opacity(0), opaqueCurrentColor],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    }
                    .frame(height: 12)
                    .clipShape(Capsule(style: .continuous))
                    .overlay {
                        Capsule(style: .continuous)
                            .strokeBorder(FMColor.hairlineHighlight(colorScheme), lineWidth: 0.5)
                    }

                    Circle()
                        .fill(FMColorMath.color(from: hsba))
                        .frame(width: thumbDiameter, height: thumbDiameter)
                        .background {
                            FMCheckerboardView(squareSize: 4).clipShape(Circle())
                        }
                        .overlay {
                            Circle().strokeBorder(.white, lineWidth: 2.5)
                        }
                        .shadow(color: .black.opacity(0.28), radius: 3, y: 1)
                        .offset(x: offsetX)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { gesture in
                            isDraggingAlpha = true
                            let nextAlpha = min(max(Double((gesture.location.x - thumbDiameter / 2) / usable), 0), 1)
                            hsba.alpha = nextAlpha
                            commitHSBA()
                        }
                        .onEnded { _ in
                            isDraggingAlpha = false
                            recentStore.record(selection)
                        }
                )
            }
            .frame(height: 22)
        }
        .fmAnimation(.micro, value: isDraggingAlpha)
    }

    // MARK: Live Hex Input + Copy Button

    private var hexControlRow: some View {
        let fieldShape = RoundedRectangle(cornerRadius: 8, style: .continuous)

        return HStack(spacing: FMSpacing.xs) {
            ZStack {
                if supportsOpacity {
                    FMCheckerboardView(squareSize: 5)
                }
                selection
            }
            .frame(width: 28, height: 28)
            .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .strokeBorder(FMColor.hairlineHighlight(colorScheme), lineWidth: 0.75)
            }

            TextField("#RRGGBB", text: $hexText)
                .textFieldStyle(.plain)
                .font(.fmMono)
                .foregroundStyle(.primary)
                .padding(.horizontal, 9)
                .frame(height: 28)
                .background(FMColor.controlFill(colorScheme), in: fieldShape)
                .overlay {
                    fieldShape.strokeBorder(FMColor.hairlineHighlight(colorScheme), lineWidth: 0.6)
                }
                .focused($isHexFocused)
                .focusEffectDisabled()
                .fmFocusRing(isFocused: isHexFocused, cornerRadius: 8)
                .onChange(of: hexText) { _, newText in
                    guard isHexFocused else { return }
                    applyHexInput(newText, allowShort: false)
                }
                .onSubmit {
                    applyHexInput(hexText, allowShort: true)
                    hexText = canonicalHex
                }
                .onChange(of: isHexFocused) { _, focused in
                    if !focused {
                        applyHexInput(hexText, allowShort: true)
                        hexText = canonicalHex
                    }
                }

            Button {
                let valueToCopy = canonicalHex
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(valueToCopy, forType: .string)
                copiedHex = true
                FMHaptics.perform(.alignment, enabled: theme.hapticsEnabled)
                Task { @MainActor in
                    try? await Task.sleep(for: .seconds(1.4))
                    copiedHex = false
                }
            } label: {
                Image(systemName: copiedHex ? "checkmark" : "doc.on.doc")
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(copiedHex ? FMColor.green : .secondary)
                    .frame(width: 28, height: 28)
                    .background(FMColor.controlFill(colorScheme), in: fieldShape)
                    .overlay {
                        fieldShape.strokeBorder(FMColor.hairlineHighlight(colorScheme), lineWidth: 0.6)
                    }
            }
            .buttonStyle(.plain)
            .focusEffectDisabled()
            .accessibilityLabel(copiedHex ? "Hex Color Copied" : "Copy Hex Color")
            .fmAnimation(.micro, value: copiedHex)
        }
    }

    // MARK: Presets & Recent Swatches

    private var swatchesSection: some View {
        VStack(alignment: .leading, spacing: FMSpacing.xs) {
            if !presets.isEmpty {
                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 8),
                    spacing: 6
                ) {
                    ForEach(Array(presets.prefix(16).enumerated()), id: \.offset) { _, color in
                        studioSwatchDot(color: color)
                    }
                }
            }

            if !recentStore.colors.isEmpty {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Recent")
                        .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)

                    HStack(spacing: 6) {
                        ForEach(Array(recentStore.colors.prefix(8).enumerated()), id: \.offset) { _, color in
                            studioSwatchDot(color: color)
                        }
                        Spacer(minLength: 0)
                    }
                }
            }
        }
    }

    private func studioSwatchDot(color: Color) -> some View {
        let isSelected = FMColorMath.colorsApproximatelyEqual(selection, color)
        return Button {
            let incoming = FMColorMath.rgba(from: color)
            var nextHSB = FMColorMath.rgbToHSB(incoming)
            if !supportsOpacity {
                nextHSB.alpha = 1.0
            }
            hsba = nextHSB
            commitHSBA()
            FMHaptics.perform(.alignment, enabled: theme.hapticsEnabled)
        } label: {
            Circle()
                .fill(color)
                .frame(width: 22, height: 22)
                .overlay {
                    if isSelected {
                        Circle()
                            .strokeBorder(.white, lineWidth: 2)
                            .padding(2)
                    } else {
                        Circle()
                            .strokeBorder(Color.black.opacity(colorScheme == .dark ? 0.2 : 0.08), lineWidth: 0.5)
                    }
                }
        }
        .buttonStyle(.plain)
        .focusEffectDisabled()
        .accessibilityLabel("Color \(FMColorMath.formatHex(FMColorMath.rgba(from: color)))")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    // MARK: Sync Helpers

    private var canonicalHex: String {
        FMColorMath.formatHex(currentRGB, includeAlpha: supportsOpacity && currentRGB.alpha < 0.999)
    }

    private func commitHSBA() {
        let finalHSBA = supportsOpacity ? hsba : FMHSBA(hue: hsba.hue, saturation: hsba.saturation, brightness: hsba.brightness, alpha: 1.0)
        selection = FMColorMath.color(from: finalHSBA)
        if !isHexFocused {
            hexText = FMColorMath.formatHex(
                FMColorMath.hsbToRGB(finalHSBA),
                includeAlpha: supportsOpacity && finalHSBA.alpha < 0.999
            )
        }
    }

    private func applyHexInput(_ raw: String, allowShort: Bool) {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let withoutHash = trimmed.hasPrefix("#") ? String(trimmed.dropFirst()) : trimmed
        let validLength = allowShort
            ? (withoutHash.count == 3 || withoutHash.count == 4 || withoutHash.count == 6 || withoutHash.count == 8)
            : (withoutHash.count == 6 || (supportsOpacity && withoutHash.count == 8))
        guard validLength, let parsed = FMColorMath.parseHex(trimmed) else {
            return
        }
        var next = FMColorMath.rgbToHSB(parsed)
        if !supportsOpacity {
            next.alpha = 1.0
        }
        hsba = next
        selection = FMColorMath.color(from: next)
        recentStore.record(selection)
    }

    private func syncFromExternalSelection(_ newColor: Color) {
        let existingRGB = FMColorMath.hsbToRGB(hsba)
        let incomingRGB = FMColorMath.rgba(from: newColor)
        let delta = max(
            abs(existingRGB.red - incomingRGB.red),
            abs(existingRGB.green - incomingRGB.green),
            abs(existingRGB.blue - incomingRGB.blue),
            abs(existingRGB.alpha - incomingRGB.alpha)
        )
        guard delta > 0.005 else { return }
        var nextHSB = FMColorMath.rgbToHSB(incomingRGB)
        if !supportsOpacity {
            nextHSB.alpha = 1.0
        }
        hsba = nextHSB
        if !isHexFocused {
            hexText = FMColorMath.formatHex(incomingRGB, includeAlpha: supportsOpacity && incomingRGB.alpha < 0.999)
        }
    }
}

private struct FMCheckerboardView: View {
    @Environment(\.colorScheme) private var colorScheme

    let squareSize: CGFloat

    var body: some View {
        let lightTile = colorScheme == .dark ? Color(white: 0.28) : Color(white: 0.92)
        let darkTile = colorScheme == .dark ? Color(white: 0.20) : Color(white: 0.76)

        Canvas { context, size in
            let cols = Int(ceil(size.width / squareSize))
            let rows = Int(ceil(size.height / squareSize))
            for row in 0..<rows {
                for col in 0..<cols {
                    let isLight = (row + col).isMultiple(of: 2)
                    let rect = CGRect(
                        x: CGFloat(col) * squareSize,
                        y: CGFloat(row) * squareSize,
                        width: squareSize,
                        height: squareSize
                    )
                    context.fill(
                        Path(rect),
                        with: .color(isLight ? lightTile : darkTile)
                    )
                }
            }
        }
    }
}
