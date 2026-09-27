import Foundation
import OSLog
import SwiftUI
import UIKit

@MainActor
final class AppState: ObservableObject {
    @Published var route: AppRoute = .home
    @Published var commitment = Commitment()
    @Published var consequences = Consequence.defaults
    @Published var secondsRemaining = 60
    @Published var evidenceSecondsRemaining = 600
    @Published var verification: VerificationResult?
    @Published var courtCase: CourtCase?
    @Published var courtSecondsRemaining = 60
    @Published var votes: [JuryVote] = []
    @Published var aiVotes: [AIVote] = []
    @Published var winningConsequence: Consequence?
    @Published var isPreparingCourt = false
    @Published var errorMessage: String?

    private let service = SupabaseService()
    private let logger = Logger(subsystem: "com.anmolahuja.mommyai", category: "MommyCourt")
    private var taskTimer: Task<Void, Never>?
    private var evidenceTimer: Task<Void, Never>?
    private var courtTimer: Task<Void, Never>?

    var enabledConsequences: [Consequence] {
        consequences.filter(\.isEnabled)
    }

    var humanVotes: [JuryVote] {
        votes.filter { $0.voterKind == "human" }
    }

    func beginCommitment() {
        withAnimation { route = .commitment }
    }

    func showConsequences() {
        withAnimation { route = .consequences }
    }

    func requestBeforeEvidence() {
        guard enabledConsequences.count >= 2 else {
            errorMessage = "Authorize at least two consequences so the jury has a choice."
            return
        }
        withAnimation { route = .beforeEvidence }
    }

    func setBeforeImage(_ image: UIImage) {
        commitment.beforeImage = image
    }

    func setAfterImage(_ image: UIImage) {
        commitment.afterImage = image
    }

    func startCountdown() {
        secondsRemaining = commitment.deadlineSeconds
        withAnimation { route = .countdown }
        taskTimer?.cancel()
        taskTimer = Task {
            while secondsRemaining > 0, !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { return }
                secondsRemaining -= 1
            }
            guard !Task.isCancelled else { return }
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
            startEvidenceWindow()
        }
    }

    func verifyEvidence() {
        guard let beforeImage = commitment.beforeImage,
              let afterImage = commitment.afterImage else {
            errorMessage = "Mommy needs both photos."
            return
        }

        evidenceTimer?.cancel()
        withAnimation { route = .verifying }
        Task {
            do {
                let result = try await service.verifyEvidence(
                    task: commitment.taskDescription,
                    beforeImage: beforeImage,
                    afterImage: afterImage
                )
                verification = result
                UINotificationFeedbackGenerator().notificationOccurred(
                    result.passed ? .success : .error
                )
                withAnimation { route = result.passed ? .success : .failure }
            } catch {
                errorMessage = "Cloud verification failed, so demo Mommy used her backup verdict."
                verification = VerificationResult(
                    passed: false,
                    confidence: 0.91,
                    reason: "The room still contains substantial visible clutter.",
                    roast: "You rearranged the crime scene and called it cleaning."
                )
                withAnimation { route = .failure }
            }
        }
    }

    func startCourt() {
        guard let verification else { return }
        isPreparingCourt = true
        courtSecondsRemaining = 60
        votes = []
        aiVotes = []
        winningConsequence = nil
        withAnimation { route = .court }

        Task {
            do {
                let generatedAIVotes = try await service.generateAIVotes(
                    task: commitment.taskDescription,
                    failureReason: verification.reason,
                    consequences: enabledConsequences
                )
                let closesAt = Date().addingTimeInterval(60)

                if AppConfig.isSupabaseConfigured {
                    courtCase = try await service.createCourtCase(
                        task: commitment.taskDescription,
                        failureReason: verification.reason,
                        closesAt: closesAt,
                        consequences: enabledConsequences
                    )
                } else {
                    courtCase = CourtCase(
                        id: UUID(),
                        taskDescription: commitment.taskDescription,
                        failureReason: verification.reason,
                        status: "open",
                        closesAt: closesAt,
                        winningConsequenceID: nil
                    )
                }

                aiVotes = generatedAIVotes
                if let courtCase {
                    logger.info(
                        "Court opened: \(courtCase.id.uuidString, privacy: .public), AI pool: \(generatedAIVotes.count)"
                    )
                }
                isPreparingCourt = false
                runCourtCountdown()
            } catch {
                logger.error("Court setup failed: \(error.localizedDescription, privacy: .public)")
                let closesAt = Date().addingTimeInterval(60)
                isPreparingCourt = false
                errorMessage = "Court backend unavailable. Continuing with the local demo jury."
                courtCase = CourtCase(
                    id: UUID(),
                    taskDescription: commitment.taskDescription,
                    failureReason: verification.reason,
                    status: "open",
                    closesAt: closesAt,
                    winningConsequenceID: nil
                )
                aiVotes = (try? await service.generateAIVotes(
                    task: commitment.taskDescription,
                    failureReason: verification.reason,
                    consequences: enabledConsequences
                )) ?? []
                runCourtCountdown(forceMock: true)
            }
        }
    }

    func toggleConsequence(_ consequence: Consequence) {
        guard let index = consequences.firstIndex(where: { $0.id == consequence.id }) else {
            return
        }
        consequences[index].isEnabled.toggle()
    }

    func reset() {
        taskTimer?.cancel()
        evidenceTimer?.cancel()
        courtTimer?.cancel()
        commitment = Commitment()
        consequences = Consequence.defaults
        secondsRemaining = 60
        evidenceSecondsRemaining = 600
        verification = nil
        courtCase = nil
        votes = []
        aiVotes = []
        winningConsequence = nil
        errorMessage = nil
        withAnimation { route = .home }
    }

    private func startEvidenceWindow() {
        let deadline = Date().addingTimeInterval(600)
        evidenceSecondsRemaining = 600
        withAnimation { route = .afterEvidence }

        evidenceTimer?.cancel()
        evidenceTimer = Task {
            while !Task.isCancelled {
                evidenceSecondsRemaining = max(
                    0,
                    Int(ceil(deadline.timeIntervalSinceNow))
                )
                if evidenceSecondsRemaining == 0 { break }
                try? await Task.sleep(for: .seconds(1))
            }
            guard !Task.isCancelled else { return }
            verification = VerificationResult(
                passed: false,
                confidence: 1,
                reason: "No after evidence was submitted within the 10-minute evidence window.",
                roast: "The evidence went missing faster than your motivation."
            )
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            withAnimation { route = .failure }
        }
    }

    private func runCourtCountdown(forceMock: Bool = false) {
        courtTimer?.cancel()
        courtTimer = Task {
            while !Task.isCancelled {
                guard let closesAt = courtCase?.closesAt else { return }
                courtSecondsRemaining = max(
                    0,
                    Int(ceil(closesAt.timeIntervalSinceNow))
                )
                if courtSecondsRemaining == 0 { break }

                if AppConfig.isSupabaseConfigured && !forceMock {
                    await refreshVotes()
                } else {
                    stageMockHumanVotes()
                }
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { return }
            }
            guard !Task.isCancelled else { return }
            await finalizeCourt(useMock: !AppConfig.isSupabaseConfigured || forceMock)
        }
    }

    private func refreshVotes() async {
        guard let caseID = courtCase?.id else { return }
        do {
            let latestVotes = try await fetchVotesWithRetry(caseID: caseID, attempts: 1)
            let newVoteCount = latestVotes.filter { latest in
                !votes.contains(where: { $0.id == latest.id })
            }.count
            withAnimation(.snappy) {
                votes = latestVotes
            }
            if newVoteCount > 0 {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                logger.info(
                    "Received \(newVoteCount) new vote(s); total synced: \(latestVotes.count)"
                )
            }
        } catch {
            logger.warning("Vote refresh missed: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func stageMockHumanVotes() {
        guard let caseID = courtCase?.id else { return }
        if courtSecondsRemaining == 45, let choice = enabledConsequences.first(where: {
            $0.type == .grounded
        }) {
            votes.append(JuryVote(
                id: UUID(),
                caseID: caseID,
                voterID: "demo-ipad",
                consequenceID: choice.id,
                voterKind: "human",
                persona: nil,
                comment: nil,
                createdAt: nil
            ))
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
        if courtSecondsRemaining == 30, let choice = enabledConsequences.first(where: {
            $0.type == .orders
        }) {
            votes.append(JuryVote(
                id: UUID(),
                caseID: caseID,
                voterID: "demo-mac",
                consequenceID: choice.id,
                voterKind: "human",
                persona: nil,
                comment: nil,
                createdAt: nil
            ))
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
    }

    private func finalizeCourt(useMock: Bool) async {
        guard let courtCase else { return }

        if useMock {
            let openSeatVotes = aiVotesForOpenSeats()
            votes.append(contentsOf: makeAIVoteRecords(openSeatVotes, caseID: courtCase.id))
        } else {
            if let latestHumanVotes = try? await fetchVotesWithRetry(
                caseID: courtCase.id,
                attempts: 3
            ) {
                votes = latestHumanVotes
            }

            let openSeatVotes = aiVotesForOpenSeats()
            logger.info(
                "Finalizing court with \(self.votes.count) synced votes; filling \(openSeatVotes.count) AI seats"
            )
            var aiVotesSynced = true
            do {
                try await service.insertAIVotes(openSeatVotes, caseID: courtCase.id)
            } catch {
                aiVotesSynced = false
                logger.error("AI vote sync failed: \(error.localizedDescription, privacy: .public)")
            }

            if let finalVotes = try? await fetchVotesWithRetry(
                caseID: courtCase.id,
                attempts: 5
            ) {
                votes = finalVotes
            }

            if votes.count < 5 {
                let localAIVotes = makeAIVoteRecords(
                    aiVotesForOpenSeats(),
                    caseID: courtCase.id
                )
                votes.append(contentsOf: localAIVotes)
                logger.warning(
                    "Server returned \(self.votes.count - localAIVotes.count) votes; completed tally locally"
                )
            } else if !aiVotesSynced {
                logger.info("AI votes were already present when insert was retried")
            }
        }

        let tally = Dictionary(grouping: votes, by: \.consequenceID)
            .mapValues(\.count)
        winningConsequence = enabledConsequences.max {
            let lhs = tally[$0.id, default: 0]
            let rhs = tally[$1.id, default: 0]
            if lhs == rhs {
                return enabledConsequences.firstIndex(of: $0)! >
                    enabledConsequences.firstIndex(of: $1)!
            }
            return lhs < rhs
        }

        if AppConfig.isSupabaseConfigured,
           let winnerID = winningConsequence?.id {
            try? await service.closeCase(caseID: courtCase.id, winnerID: winnerID)
        }
        logger.info(
            "Court finalized with \(self.votes.count) votes; winner: \(self.winningConsequence?.title ?? "none", privacy: .public)"
        )

        UINotificationFeedbackGenerator().notificationOccurred(.success)
        try? await Task.sleep(for: .seconds(1.2))
        withAnimation { route = .verdict }
    }

    private func fetchVotesWithRetry(caseID: UUID, attempts: Int) async throws -> [JuryVote] {
        var lastError: Error = DemoServiceError.invalidResponse
        for attempt in 1...attempts {
            do {
                return try await service.fetchVotes(caseID: caseID)
            } catch {
                lastError = error
                if attempt < attempts {
                    try? await Task.sleep(for: .milliseconds(350))
                }
            }
        }
        throw lastError
    }

    private func aiVotesForOpenSeats() -> [AIVote] {
        let existingPersonas = Set(votes.compactMap(\.persona))
        let availableVotes = aiVotes.filter { !existingPersonas.contains($0.persona) }
        return Array(availableVotes.prefix(max(0, 5 - votes.count)))
    }

    private func makeAIVoteRecords(_ sourceVotes: [AIVote], caseID: UUID) -> [JuryVote] {
        sourceVotes.compactMap { vote in
            guard let consequenceID = UUID(uuidString: vote.choice) else { return nil }
            return JuryVote(
                id: UUID(),
                caseID: caseID,
                voterID: "ai-\(vote.persona)",
                consequenceID: consequenceID,
                voterKind: "ai",
                persona: vote.persona,
                comment: vote.comment,
                createdAt: nil
            )
        }
    }
}
