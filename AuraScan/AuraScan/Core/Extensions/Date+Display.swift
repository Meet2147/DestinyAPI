//
//  Date+Display.swift
//  AuraScan
//

import Foundation

extension Date {
    /// "2 hours ago" — used in history rows.
    var relativeDescription: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: self, relativeTo: .now)
    }

    var readingTimestamp: String {
        formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated).hour().minute())
    }
}
