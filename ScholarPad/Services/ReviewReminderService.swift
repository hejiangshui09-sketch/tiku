import Foundation
@preconcurrency import UserNotifications

@MainActor
final class ReviewReminderService {
    private let center = UNUserNotificationCenter.current()
    private let identifier = "scholarpad.daily-review"

    func enableDailyReminder(hour: Int = 20) async throws -> Bool {
        let granted = try await center.requestAuthorization(options: [.alert, .badge, .sound])
        guard granted else { return false }

        center.removePendingNotificationRequests(withIdentifiers: [identifier])

        let content = UNMutableNotificationContent()
        content.title = "知识学习库 · 今日复习"
        content.body = "用几分钟完成到期题目，让知识保持清晰。"
        content.sound = .default

        var components = DateComponents()
        components.hour = hour
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        try await center.add(UNNotificationRequest(identifier: identifier, content: content, trigger: trigger))
        return true
    }

    func disableDailyReminder() {
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
    }
}
