import Foundation

enum QuestionEvaluator {
    static func isCorrect(_ question: Question, selectedAnswers: Set<String>) -> Bool {
        switch question.type {
        case .singleChoice, .multipleChoice:
            let allowedChoices = Set((question.options ?? [:]).keys.map { normalize($0) })
            let expectedChoices = Set(
                question.answer
                    .uppercased()
                    .map { String($0) }
                    .filter { allowedChoices.contains($0) }
            )
            let selectedChoices = Set(selectedAnswers.map { normalize($0) })
            return !expectedChoices.isEmpty && expectedChoices == selectedChoices
        case .trueFalse:
            guard let expected = normalizedTrueFalseAnswer(question.answer) else {
                return false
            }
            return selectedAnswers == [expected]
        case .shortAnswer:
            return false
        }
    }

    private static func normalize(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
    }

    private static func normalizedTrueFalseAnswer(_ answer: String) -> String? {
        let normalized = answer.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalized.isEmpty else { return nil }

        if ["不正确", "不对", "不是", "错误", "incorrect", "false", "错", "否"].contains(where: {
            normalized.contains($0)
        }) {
            return "错"
        }
        if ["正确", "true", "对", "是"].contains(where: { normalized.contains($0) }) {
            return "对"
        }
        return nil
    }
}
