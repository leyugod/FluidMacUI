import Foundation
import SwiftUI
import Testing
@testable import FluidMacUI

@Suite("Calendar & Color Picker Math Tests")
struct PickersLogicTests {
    // MARK: - Helper Calendar (Fixed UTC Gregorian for Deterministic Tests)

    private static func utcCalendar(firstWeekday: Int = 1) -> Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        cal.locale = Locale(identifier: "en_US_POSIX")
        cal.firstWeekday = firstWeekday
        return cal
    }

    private static func makeDate(
        year: Int,
        month: Int,
        day: Int,
        hour: Int = 0,
        minute: Int = 0,
        second: Int = 0,
        calendar: Calendar
    ) -> Date {
        let comps = DateComponents(
            timeZone: calendar.timeZone,
            year: year,
            month: month,
            day: day,
            hour: hour,
            minute: minute,
            second: second
        )
        return calendar.date(from: comps)!
    }

    // MARK: - FMCalendarMath Tests

    @Test("Month grid always generates 42 contiguous days aligned to firstWeekday")
    func monthGridStructureAndAlignment() {
        let sundayCal = Self.utcCalendar(firstWeekday: 1)
        // February 2024 was a leap year; Feb 1, 2024 was a Thursday (weekday 5)
        let feb2024 = Self.makeDate(year: 2024, month: 2, day: 15, calendar: sundayCal)
        let today = Self.makeDate(year: 2024, month: 2, day: 29, calendar: sundayCal)

        let grid = FMCalendarMath.monthGrid(for: feb2024, referenceToday: today, calendar: sundayCal)
        #expect(grid.count == 42)
        #expect(sundayCal.component(.weekday, from: grid[0].date) == 1)

        let inMonthDays = grid.filter(\.isInDisplayedMonth)
        #expect(inMonthDays.count == 29) // Leap year February has 29 days
        #expect(inMonthDays.first?.dayNumber == 1)
        #expect(inMonthDays.last?.dayNumber == 29)

        let todayCells = grid.filter(\.isToday)
        #expect(todayCells.count == 1)
        #expect(todayCells[0].dayNumber == 29)

        // Verify Monday-first calendar alignment
        let mondayCal = Self.utcCalendar(firstWeekday: 2)
        let mondayGrid = FMCalendarMath.monthGrid(for: feb2024, referenceToday: today, calendar: mondayCal)
        #expect(mondayGrid.count == 42)
        #expect(mondayCal.component(.weekday, from: mondayGrid[0].date) == 2)

        // All 42 days must be strictly consecutive 1-day steps
        for idx in 1..<mondayGrid.count {
            let expectedNext = mondayCal.date(byAdding: .day, value: 1, to: mondayGrid[idx - 1].date)!
            #expect(mondayCal.isDate(mondayGrid[idx].date, inSameDayAs: expectedNext))
        }
    }

    @Test("Weekday symbols rotate cleanly according to calendar.firstWeekday")
    func weekdaySymbolRotation() {
        let sundaySymbols = FMCalendarMath.weekdaySymbols(calendar: Self.utcCalendar(firstWeekday: 1))
        let mondaySymbols = FMCalendarMath.weekdaySymbols(calendar: Self.utcCalendar(firstWeekday: 2))

        #expect(sundaySymbols.count == 7)
        #expect(mondaySymbols.count == 7)
        #expect(sundaySymbols[0] == "S")
        #expect(mondaySymbols[0] == "M")
        #expect(mondaySymbols[6] == sundaySymbols[0])
    }

    @Test("Month shifting and startOfMonth navigate cleanly across year boundaries")
    func monthNavigationAcrossYearBoundaries() {
        let cal = Self.utcCalendar()
        let dec2025 = Self.makeDate(year: 2025, month: 12, day: 19, hour: 15, minute: 30, calendar: cal)
        let jan2026 = FMCalendarMath.shiftMonth(dec2025, by: 1, calendar: cal)
        let nov2025 = FMCalendarMath.shiftMonth(dec2025, by: -1, calendar: cal)

        #expect(cal.component(.year, from: jan2026) == 2026)
        #expect(cal.component(.month, from: jan2026) == 1)
        #expect(cal.component(.day, from: jan2026) == 1)

        #expect(cal.component(.year, from: nov2025) == 2025)
        #expect(cal.component(.month, from: nov2025) == 11)
        #expect(cal.component(.day, from: nov2025) == 1)

        let clampedMonth = FMCalendarMath.startOfMonth(year: 2026, month: 99, calendar: cal)
        #expect(cal.component(.month, from: clampedMonth) == 12)
    }

    @Test("Date clamping and range normalization enforce valid bounds")
    func dateClampingAndRangeNormalization() {
        let cal = Self.utcCalendar()
        let minDate = Self.makeDate(year: 2026, month: 3, day: 10, hour: 9, minute: 0, calendar: cal)
        let midDate = Self.makeDate(year: 2026, month: 3, day: 15, hour: 12, minute: 0, calendar: cal)
        let maxDate = Self.makeDate(year: 2026, month: 3, day: 20, hour: 18, minute: 0, calendar: cal)
        let before = Self.makeDate(year: 2026, month: 3, day: 1, calendar: cal)
        let after = Self.makeDate(year: 2026, month: 4, day: 1, calendar: cal)
        let bounds = minDate...maxDate

        #expect(FMCalendarMath.clamp(before, to: bounds) == minDate)
        #expect(FMCalendarMath.clamp(after, to: bounds) == maxDate)
        #expect(FMCalendarMath.clamp(midDate, to: bounds) == midDate)
        #expect(FMCalendarMath.clamp(before, to: nil) == before)

        #expect(FMCalendarMath.isDaySelectable(minDate, in: bounds, calendar: cal))
        #expect(FMCalendarMath.isDaySelectable(midDate, in: bounds, calendar: cal))
        #expect(FMCalendarMath.isDaySelectable(maxDate, in: bounds, calendar: cal))
        #expect(!FMCalendarMath.isDaySelectable(before, in: bounds, calendar: cal))
        #expect(!FMCalendarMath.isDaySelectable(after, in: bounds, calendar: cal))

        let reversed = FMCalendarMath.normalizedRange(maxDate, minDate)
        #expect(reversed.lowerBound == minDate)
        #expect(reversed.upperBound == maxDate)

        let ordered = FMCalendarMath.normalizedRange(minDate, maxDate)
        #expect(ordered == reversed)

        #expect(FMCalendarMath.isDay(midDate, within: reversed, calendar: cal))
        #expect(!FMCalendarMath.isDay(before, within: reversed, calendar: cal))
    }

    @Test("Merging day preserves time components and updating time wraps cleanly")
    func dayMergingAndTimeUpdating() {
        let cal = Self.utcCalendar()
        let source = Self.makeDate(year: 2026, month: 5, day: 1, hour: 14, minute: 45, second: 30, calendar: cal)
        let pickedDay = Self.makeDate(year: 2026, month: 6, day: 20, hour: 0, minute: 0, calendar: cal)

        let merged = FMCalendarMath.mergingDay(pickedDay, preservingTimeFrom: source, calendar: cal)
        #expect(cal.component(.year, from: merged) == 2026)
        #expect(cal.component(.month, from: merged) == 6)
        #expect(cal.component(.day, from: merged) == 20)
        #expect(cal.component(.hour, from: merged) == 14)
        #expect(cal.component(.minute, from: merged) == 45)
        #expect(cal.component(.second, from: merged) == 30)

        let wrappedForward = FMCalendarMath.updatingTime(of: merged, hour: 24, minute: 60, calendar: cal)
        #expect(cal.component(.hour, from: wrappedForward) == 0)
        #expect(cal.component(.minute, from: wrappedForward) == 0)

        let wrappedBackward = FMCalendarMath.updatingTime(of: merged, hour: -1, minute: -1, calendar: cal)
        #expect(cal.component(.hour, from: wrappedBackward) == 23)
        #expect(cal.component(.minute, from: wrappedBackward) == 59)
    }

    // MARK: - FMColorMath Tests

    @Test("HSB <-> RGB conversion accurately maps primary, secondary, and grayscale colors")
    func hsbToRGBAndBackRoundTrip() {
        let samples: [(FMHSBA, FMRGBA)] = [
            (FMHSBA(hue: 0.0, saturation: 1.0, brightness: 1.0), FMRGBA(red: 1, green: 0, blue: 0)),
            (FMHSBA(hue: 1.0 / 3.0, saturation: 1.0, brightness: 1.0), FMRGBA(red: 0, green: 1, blue: 0)),
            (FMHSBA(hue: 2.0 / 3.0, saturation: 1.0, brightness: 1.0), FMRGBA(red: 0, green: 0, blue: 1)),
            (FMHSBA(hue: 0.5, saturation: 1.0, brightness: 1.0), FMRGBA(red: 0, green: 1, blue: 1)),
            (FMHSBA(hue: 0.0, saturation: 0.0, brightness: 0.5), FMRGBA(red: 0.5, green: 0.5, blue: 0.5)),
            (FMHSBA(hue: 0.0, saturation: 0.0, brightness: 0.0), FMRGBA(red: 0, green: 0, blue: 0)),
            (FMHSBA(hue: 0.0, saturation: 0.0, brightness: 1.0), FMRGBA(red: 1, green: 1, blue: 1))
        ]

        for (hsb, expectedRGB) in samples {
            let actualRGB = FMColorMath.hsbToRGB(hsb)
            #expect(abs(actualRGB.red - expectedRGB.red) < 0.0001)
            #expect(abs(actualRGB.green - expectedRGB.green) < 0.0001)
            #expect(abs(actualRGB.blue - expectedRGB.blue) < 0.0001)

            let roundTrippedHSB = FMColorMath.rgbToHSB(actualRGB)
            #expect(abs(roundTrippedHSB.saturation - hsb.saturation) < 0.0001)
            #expect(abs(roundTrippedHSB.brightness - hsb.brightness) < 0.0001)
            if hsb.saturation > 0 {
                #expect(abs(roundTrippedHSB.hue - hsb.hue) < 0.0001)
            }
        }

        // Arbitrary mid-tone round trip
        let custom = FMRGBA(red: 0.25, green: 0.62, blue: 0.91, alpha: 0.75)
        let converted = FMColorMath.hsbToRGB(FMColorMath.rgbToHSB(custom))
        #expect(abs(converted.red - custom.red) < 0.0001)
        #expect(abs(converted.green - custom.green) < 0.0001)
        #expect(abs(converted.blue - custom.blue) < 0.0001)
        #expect(abs(converted.alpha - custom.alpha) < 0.0001)
    }

    @Test("Hex parsing handles 3, 4, 6, and 8 digit formats and rejects malformed input")
    func hexParsingAndFormatting() {
        let hex6 = FMColorMath.parseHex("#0A84FF")
        #expect(hex6 != nil)
        #expect(FMColorMath.formatHex(hex6!) == "#0A84FF")

        let noHash = FMColorMath.parseHex("  ff3b30  ")
        #expect(noHash != nil)
        #expect(FMColorMath.formatHex(noHash!) == "#FF3B30")

        let hex3 = FMColorMath.parseHex("#0F8")
        #expect(hex3 != nil)
        #expect(FMColorMath.formatHex(hex3!) == "#00FF88")

        let hex4 = FMColorMath.parseHex("#F0A8")
        #expect(hex4 != nil)
        #expect(FMColorMath.formatHex(hex4!, includeAlpha: true) == "#FF00AA88")

        let hex8 = FMColorMath.parseHex("#1E2A3B80")
        #expect(hex8 != nil)
        #expect(FMColorMath.formatHex(hex8!, includeAlpha: true) == "#1E2A3B80")
        #expect(FMColorMath.formatHex(hex8!, includeAlpha: false) == "#1E2A3B")

        #expect(FMColorMath.parseHex("") == nil)
        #expect(FMColorMath.parseHex("#12") == nil)
        #expect(FMColorMath.parseHex("#12345") == nil)
        #expect(FMColorMath.parseHex("#GGGGGG") == nil)
        #expect(FMColorMath.parseHex("##AABBCC") == nil)
    }

    @Test("Color structs clamp out-of-range channel inputs safely")
    func colorChannelClamping() {
        let clampedRGB = FMRGBA(red: -0.5, green: 1.8, blue: 0.5, alpha: 2.0)
        #expect(clampedRGB.red == 0.0)
        #expect(clampedRGB.green == 1.0)
        #expect(clampedRGB.blue == 0.5)
        #expect(clampedRGB.alpha == 1.0)
        #expect(FMColorMath.formatHex(clampedRGB) == "#00FF80")

        let clampedHSB = FMHSBA(hue: 1.5, saturation: -0.2, brightness: 1.2, alpha: -1.0)
        #expect(clampedHSB.hue == 1.0)
        #expect(clampedHSB.saturation == 0.0)
        #expect(clampedHSB.brightness == 1.0)
        #expect(clampedHSB.alpha == 0.0)
    }

    @Test("SwiftUI Color sRGB bridge round-trips accurately and compares with tolerance")
    func swiftUIColorBridgeAndEquality() {
        let original = FMRGBA(red: 0.35, green: 0.34, blue: 0.84, alpha: 1.0)
        let swiftUIColor = FMColorMath.color(from: original)
        let extracted = FMColorMath.rgba(from: swiftUIColor)

        #expect(abs(extracted.red - original.red) < 0.01)
        #expect(abs(extracted.green - original.green) < 0.01)
        #expect(abs(extracted.blue - original.blue) < 0.01)
        #expect(FMColorMath.colorsApproximatelyEqual(swiftUIColor, FMColor.indigo))
        #expect(!FMColorMath.colorsApproximatelyEqual(FMColor.blue, FMColor.red))
    }
}
