@preconcurrency import ActivityKit
import Foundation
import AppIntents

struct TimerAttributes: ActivityAttributes, Sendable {
    public struct ContentState: Codable, Hashable, Sendable {
        var isPaused: Bool
        var totalWorkedSeconds: Int
        var lastStartDate: Date?
        var goalSeconds: Int
    }
    var goalName: String
}

@available(iOS 16.1, *)
struct ToggleTimerIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Mola / Devam"
    init() {}
    
    func perform() async throws -> some IntentResult {
        if let activity = Activity<TimerAttributes>.activities.first {
            var state = activity.content.state
            if state.isPaused {
                state.isPaused = false
                state.lastStartDate = Date()
            } else {
                state.isPaused = true
                if let start = state.lastStartDate {
                    state.totalWorkedSeconds += Int(Date().timeIntervalSince(start))
                }
                state.lastStartDate = nil
            }
            await activity.update(ActivityContent(state: state, staleDate: nil))
        }
        return .result()
    }
}

@available(iOS 16.1, *)
struct EndTimerIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Bitir"
    init() {}
    
    func perform() async throws -> some IntentResult {
        if let activity = Activity<TimerAttributes>.activities.first {
            var state = activity.content.state
            if !state.isPaused {
                if let start = state.lastStartDate {
                    state.totalWorkedSeconds += Int(Date().timeIntervalSince(start))
                }
                state.isPaused = true
                state.lastStartDate = nil
            }
            await activity.end(ActivityContent(state: state, staleDate: nil), dismissalPolicy: .default)
        }
        return .result()
    }
}
