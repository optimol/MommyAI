import Foundation
import UIKit

enum DemoServiceError: LocalizedError {
    case invalidConfiguration
    case invalidResponse
    case requestFailed(Int, String)

    var errorDescription: String? {
        switch self {
        case .invalidConfiguration:
            "Supabase is not configured."
        case .invalidResponse:
            "Mommy received an unreadable response."
        case let .requestFailed(status, message):
            "Request failed (\(status)): \(message)"
        }
    }
}

struct SupabaseService {
    private let encoder = JSONEncoder()
    private let isoFormatter = ISO8601DateFormatter()

    func verifyEvidence(
        task: String,
        beforeImage: UIImage,
        afterImage: UIImage
    ) async throws -> VerificationResult {
        guard AppConfig.isSupabaseConfigured else {
            try await Task.sleep(for: .seconds(1.8))
            return VerificationResult(
                passed: false,
                confidence: 0.94,
                reason: "Clothing and clutter remain scattered across the bed and floor.",
                roast: "You moved approximately three shirts and expected applause?"
            )
        }

        let body: [String: Any] = [
            "task": task,
            "before_image_base64": imageData(beforeImage).base64EncodedString(),
            "after_image_base64": imageData(afterImage).base64EncodedString()
        ]
        let data = try await request(
            path: "/functions/v1/verify-evidence",
            method: "POST",
            body: body
        )
        return try JSONDecoder.supabase.decode(VerificationResult.self, from: data)
    }

    func createCourtCase(
        task: String,
        failureReason: String,
        closesAt: Date,
        consequences: [Consequence]
    ) async throws -> CourtCase {
        let caseID = UUID()
        let caseBody: [String: Any] = [
            "id": caseID.uuidString,
            "task_description": task,
            "failure_reason": failureReason,
            "status": "open",
            "closes_at": isoFormatter.string(from: closesAt)
        ]
        let caseData = try await request(
            path: "/rest/v1/cases",
            method: "POST",
            body: caseBody,
            preferRepresentation: true
        )
        guard let courtCase = try JSONDecoder.supabase
            .decode([CourtCase].self, from: caseData).first else {
            throw DemoServiceError.invalidResponse
        }

        let consequenceBody: [[String: Any]] = consequences.map {
            [
                "id": $0.id.uuidString,
                "case_id": caseID.uuidString,
                "type": $0.type.rawValue,
                "title": $0.title,
                "payload": $0.payload
            ]
        }
        _ = try await request(
            path: "/rest/v1/consequences",
            method: "POST",
            body: consequenceBody
        )
        return courtCase
    }

    func generateAIVotes(
        task: String,
        failureReason: String,
        consequences: [Consequence]
    ) async throws -> [AIVote] {
        guard AppConfig.isSupabaseConfigured else {
            return [
                AIVote(
                    persona: "Tiger Mom",
                    choice: consequences.first(where: { $0.type == .grounded })?.id.uuidString
                        ?? consequences[0].id.uuidString,
                    comment: "Your room failed inspection, so the distraction rectangle is grounded. Brick the phone."
                ),
                AIVote(
                    persona: "Gentle Mom",
                    choice: consequences.first(where: { $0.type == .grounded })?.id.uuidString
                        ?? consequences[0].id.uuidString,
                    comment: "Your phone deserves a two-hour nap, and your laundry deserves to finally meet a hanger."
                ),
                AIVote(
                    persona: "Corporate Mom",
                    choice: consequences.first(where: { $0.type == .grounded })?.id.uuidString
                        ?? consequences[0].id.uuidString,
                    comment: "We are bricking the distraction rectangle to remediate this performance gap."
                ),
                AIVote(
                    persona: "Cool Mom",
                    choice: consequences.first(where: { $0.type == .wasteMoney })?.id.uuidString
                        ?? consequences[0].id.uuidString,
                    comment: "No judgment, bestie—just adult diapers arriving with your name on the box."
                ),
                AIVote(
                    persona: "Passive-Aggressive Mom",
                    choice: consequences.last(where: { $0.type == .embarrass })?.id.uuidString
                        ?? consequences[0].id.uuidString,
                    comment: "Send Dad the approved spicy pic. I’m sure he’ll be thrilled you found time for that."
                )
            ]
        }

        let choices = consequences.map {
            [
                "id": $0.id.uuidString,
                "title": $0.title,
                "type": $0.type.rawValue
            ]
        }
        let data = try await request(
            path: "/functions/v1/ai-jury",
            method: "POST",
            body: [
                "task": task,
                "failure_reason": failureReason,
                "consequences": choices
            ]
        )
        return try JSONDecoder.supabase.decode(AIJuryResponse.self, from: data).votes
    }

    func fetchVotes(caseID: UUID) async throws -> [JuryVote] {
        let query = "?case_id=eq.\(caseID.uuidString)&select=id,case_id,voter_id,consequence_id,voter_kind,persona,comment"
        let data = try await request(path: "/rest/v1/votes\(query)", method: "GET")
        return try JSONDecoder.supabase.decode([JuryVote].self, from: data)
    }

    func insertAIVotes(_ votes: [AIVote], caseID: UUID) async throws {
        let body: [[String: Any]] = votes.map {
            [
                "case_id": caseID.uuidString,
                "voter_id": "ai-\($0.persona.lowercased().replacingOccurrences(of: " ", with: "-"))",
                "consequence_id": $0.choice,
                "voter_kind": "ai",
                "persona": $0.persona,
                "comment": $0.comment
            ]
        }
        _ = try await request(path: "/rest/v1/votes", method: "POST", body: body)
    }

    func closeCase(caseID: UUID, winnerID: UUID) async throws {
        let body: [String: Any] = [
            "status": "closed",
            "winning_consequence_id": winnerID.uuidString
        ]
        _ = try await request(
            path: "/rest/v1/cases?id=eq.\(caseID.uuidString)",
            method: "PATCH",
            body: body
        )
    }

    private func imageData(_ image: UIImage) -> Data {
        let maxDimension: CGFloat = 1280
        let scale = min(1, maxDimension / max(image.size.width, image.size.height))
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: size)
        let resized = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
        return resized.jpegData(compressionQuality: 0.72) ?? Data()
    }

    private func request(
        path: String,
        method: String,
        body: Any? = nil,
        preferRepresentation: Bool = false
    ) async throws -> Data {
        guard AppConfig.isSupabaseConfigured,
              let url = URL(string: AppConfig.supabaseURL + path) else {
            throw DemoServiceError.invalidConfiguration
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue(AppConfig.supabasePublishableKey, forHTTPHeaderField: "apikey")
        request.setValue(
            "Bearer \(AppConfig.supabasePublishableKey)",
            forHTTPHeaderField: "Authorization"
        )
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if preferRepresentation {
            request.setValue("return=representation", forHTTPHeaderField: "Prefer")
        }
        if let body {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let response = response as? HTTPURLResponse else {
            throw DemoServiceError.invalidResponse
        }
        guard (200..<300).contains(response.statusCode) else {
            throw DemoServiceError.requestFailed(
                response.statusCode,
                String(data: data, encoding: .utf8) ?? "Unknown error"
            )
        }
        return data
    }
}
