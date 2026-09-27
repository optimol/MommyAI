import SwiftUI

@main
struct MommyAIApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
                .preferredColorScheme(.dark)
        }
    }
}

struct RootView: View {
    @EnvironmentObject private var state: AppState

    var body: some View {
        ZStack {
            MommyTheme.background.ignoresSafeArea()

            Group {
                switch state.route {
                case .home:
                    HomeView()
                case .commitment:
                    CommitmentView()
                case .consequences:
                    ConsequenceSetupView()
                case .beforeEvidence:
                    EvidenceView(kind: .before)
                case .countdown:
                    DeadlineView()
                case .afterEvidence:
                    EvidenceView(kind: .after)
                case .verifying:
                    VerificationView()
                case .success:
                    SuccessView()
                case .failure:
                    FailureView()
                case .court:
                    CourtView()
                case .verdict:
                    VerdictView()
                }
            }
            .transition(.opacity.combined(with: .scale(scale: 0.98)))
        }
        .tint(MommyTheme.hotPink)
        .alert(
            "Mommy says…",
            isPresented: Binding(
                get: { state.errorMessage != nil },
                set: { if !$0 { state.errorMessage = nil } }
            ),
            actions: {
                Button("Understood") { state.errorMessage = nil }
            },
            message: {
                Text(state.errorMessage ?? "")
            }
        )
    }
}
