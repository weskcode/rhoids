import WidgetKit
import Foundation

struct RHOIDSEntry: TimelineEntry {
    let date: Date
    let timerEndDate: Date?
    let presetName: String?
    let isRunning: Bool
    let duration: TimeInterval
    var family: WidgetFamily = .systemSmall
}
