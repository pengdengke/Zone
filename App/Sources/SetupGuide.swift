import Foundation

struct SetupChecklistStep: Identifiable, Equatable {
    let id: String
    let title: String
    let detail: String
    let isComplete: Bool
}
