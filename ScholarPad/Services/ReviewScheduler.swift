import Foundation

enum ReviewScheduler {
    static func updatedItem(
        existing: ReviewItem?,
        id: String,
        courseID: String,
        chapterID: Int,
        questionType: QuestionType,
        questionID: Int,
        correct: Bool,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> ReviewItem {
        var item = existing ?? ReviewItem(
            id: id,
            courseID: courseID,
            chapterID: chapterID,
            questionType: questionType,
            questionID: questionID,
            nextReviewAt: now,
            intervalDays: 0,
            correctStreak: 0,
            lapses: 0,
            lastReviewedAt: now
        )

        if correct {
            item.correctStreak += 1
            item.intervalDays = item.intervalDays == 0 ? 1 : min(item.intervalDays * 2, 60)
            item.nextReviewAt = calendar.date(
                byAdding: .day,
                value: item.intervalDays,
                to: now
            ) ?? now
        } else {
            item.correctStreak = 0
            item.intervalDays = 0
            item.lapses += 1
            item.nextReviewAt = now
        }
        item.lastReviewedAt = now
        return item
    }
}

