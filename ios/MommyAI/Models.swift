import Foundation
import UIKit

enum AppRoute: Equatable {
    case home
    case commitment
    case consequences
    case beforeEvidence
    case countdown
    case afterEvidence
    case verifying
    case success
    case failure
    case court
    case verdict
}

struct Commitment {
    var taskDescription = "Clean my room"
    var deadlineSeconds = 60
    var beforeImage: UIImage?
    var afterImage: UIImage?
}

enum ConsequenceKind: String, Codable, CaseIterable {
    case grounded
    case orders
    case embarrass
    case wasteMoney = "waste_money"

    var icon: String {
        switch self {
        case .grounded: "lock.fill"
        case .orders: "figure.strengthtraining.traditional"
        case .embarrass: "message.badge.filled.fill"
        case .wasteMoney: "cart.fill.badge.minus"
        }
    }
}

struct Consequence: Identifiable, Codable, Equatable {
    let id: UUID
    let type: ConsequenceKind
    let title: String
    let detail: String
    let payload: [String: String]
    var isEnabled: Bool

    init(
        id: UUID = UUID(),
        type: ConsequenceKind,
        title: String,
        detail: String,
        payload: [String: String],
        isEnabled: Bool = true
    ) {
        self.id = id
        self.type = type
        self.title = title
        self.detail = detail
        self.payload = payload
        self.isEnabled = isEnabled
    }

    static let defaults: [Consequence] = [
        Consequence(
            type: .grounded,
            title: "Brick phone for 2 hours",
            detail: "Block every non-essential app; keep Phone, Messages, and Maps",
            payload: ["duration_minutes": "120"]
        ),
        Consequence(
            type: .orders,
            title: "30 push-ups",
            detail: "Mommy expects evidence",
            payload: ["exercise": "pushups", "count": "30"]
        ),
        Consequence(
            type: .wasteMoney,
            title: "Order adult diapers",
            detail: "$17.99 of your $20 punishment budget",
            payload: ["item": "36-pack adult diapers", "price": "17.99", "max_spend": "20"]
        ),
        Consequence(
            type: .embarrass,
            title: "Send spicy pics to Mom",
            detail: "Send a pre-approved suggestive photo",
            payload: ["recipient": "Mom", "asset": "approved_spicy_photo", "delivery": "simulated"]
        ),
        Consequence(
            type: .embarrass,
            title: "Send spicy pics to Dad",
            detail: "Send a pre-approved suggestive photo",
            payload: ["recipient": "Dad", "asset": "approved_spicy_photo", "delivery": "simulated"]
        )
    ]
}

struct VerificationResult: Codable {
    let passed: Bool
    let confidence: Double
    let reason: String
    let roast: String?
}

struct CourtCase: Identifiable, Codable {
    let id: UUID
    let taskDescription: String
    let failureReason: String
    let status: String
    let closesAt: Date
    let winningConsequenceID: UUID?

    enum CodingKeys: String, CodingKey {
        case id
        case taskDescription = "task_description"
        case failureReason = "failure_reason"
        case status
        case closesAt = "closes_at"
        case winningConsequenceID = "winning_consequence_id"
    }
}

struct JuryVote: Identifiable, Codable {
    let id: UUID
    let caseID: UUID
    let voterID: String
    let consequenceID: UUID
    let voterKind: String
    let persona: String?
    let comment: String?
    let createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case caseID = "case_id"
        case voterID = "voter_id"
        case consequenceID = "consequence_id"
        case voterKind = "voter_kind"
        case persona
        case comment
        case createdAt = "created_at"
    }
}

struct AIVote: Codable, Identifiable {
    var id: String { persona }
    let persona: String
    let choice: String
    let comment: String
}

struct AIJuryResponse: Codable {
    let votes: [AIVote]
}

extension JSONDecoder {
    static var supabase: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
