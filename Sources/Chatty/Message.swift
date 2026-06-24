import Foundation

struct Message: Identifiable, Equatable {
    let id = UUID()
    var text: String
    let isUser: Bool
}
