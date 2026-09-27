import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var state: AppState

    var body: some View {
        ScreenContainer {
            VStack(spacing: 28) {
                Spacer(minLength: 28)

                ZStack {
                    Circle()
                        .fill(MommyTheme.hotPink.opacity(0.18))
                        .frame(width: 150, height: 150)
                        .blur(radius: 10)
                    Text("👩🏻")
                        .font(.system(size: 102))
                }

                VStack(spacing: 10) {
                    Eyebrow(text: "weaponized accountability")
                    Text("AI MOMMY")
                        .font(.system(size: 52, weight: .black, design: .rounded))
                        .tracking(-2)
                    Text("Because apparently self-discipline\nwas too much to ask.")
                        .font(.title3.weight(.medium))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                }

                VStack(spacing: 12) {
                    Label("Objective proof", systemImage: "camera.viewfinder")
                    Label("Internet parents", systemImage: "person.3.fill")
                    Label("Consequences you authorized", systemImage: "checkmark.shield.fill")
                }
                .font(.subheadline.weight(.bold))
                .frame(maxWidth: .infinity, alignment: .leading)
                .mommyCard()

                MommyButton(title: "Make a commitment", icon: "arrow.right") {
                    state.beginCommitment()
                }
            }
        }
    }
}

struct CommitmentView: View {
    @EnvironmentObject private var state: AppState

    var body: some View {
        ScreenContainer {
            VStack(alignment: .leading, spacing: 24) {
                Eyebrow(text: "Step 1 of 3")
                Text("What are you\npromising?")
                    .font(.system(size: 40, weight: .black, design: .rounded))

                VStack(alignment: .leading, spacing: 10) {
                    Text("THE COMMITMENT")
                        .font(.caption.weight(.black))
                        .foregroundStyle(.secondary)
                    TextField("Clean my room", text: $state.commitment.taskDescription, axis: .vertical)
                        .font(.title3.weight(.bold))
                        .padding(16)
                        .background(Color.white.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("DEADLINE")
                        .font(.caption.weight(.black))
                        .foregroundStyle(.secondary)

                    HStack(spacing: 10) {
                        deadlineButton("1 min", seconds: 60)
                        deadlineButton("10 min", seconds: 600)
                    }
                    HStack(spacing: 10) {
                        deadlineButton("30 min", seconds: 1_800)
                        deadlineButton("1 hour", seconds: 3_600)
                    }
                    deadlineButton("1 day", seconds: 86_400)

                    Stepper(
                        "Custom: \(formattedDuration(state.commitment.deadlineSeconds))",
                        value: $state.commitment.deadlineSeconds,
                        in: 60...86_400,
                        step: 60
                    )
                    .font(.subheadline.weight(.semibold))
                    .mommyCard()
                }

                HStack {
                    Image(systemName: "camera.fill")
                        .foregroundStyle(MommyTheme.hotPink)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Proof method")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("Before + after photos")
                            .font(.headline)
                    }
                    Spacer()
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(MommyTheme.mint)
                }
                .mommyCard()

                MommyButton(
                    title: "Choose consequences",
                    icon: "arrow.right",
                    disabled: state.commitment.taskDescription.trimmingCharacters(in: .whitespaces).isEmpty
                ) {
                    state.showConsequences()
                }
            }
        }
    }

    private func deadlineButton(_ title: String, seconds: Int) -> some View {
        Button {
            state.commitment.deadlineSeconds = seconds
        } label: {
            Text(title)
                .font(.subheadline.weight(.black))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(
                    state.commitment.deadlineSeconds == seconds
                        ? MommyTheme.hotPink
                        : Color.white.opacity(0.08)
                )
                .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }

    private func formattedDuration(_ seconds: Int) -> String {
        if seconds >= 86_400 {
            return "\(seconds / 86_400) day"
        }
        if seconds >= 3_600 {
            return "\(seconds / 3_600) hr"
        }
        return "\(seconds / 60) min"
    }
}

struct ConsequenceSetupView: View {
    @EnvironmentObject private var state: AppState

    var body: some View {
        ScreenContainer {
            VStack(alignment: .leading, spacing: 20) {
                Eyebrow(text: "Step 2 of 3")
                Text("What is Mommy\nallowed to do?")
                    .font(.system(size: 38, weight: .black, design: .rounded))

                Text("The jury can only choose punishments you authorize now.")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)

                ForEach($state.consequences) { $consequence in
                    HStack(alignment: .top, spacing: 14) {
                        Image(systemName: consequence.type.icon)
                            .font(.title3)
                            .foregroundStyle(
                                consequence.isEnabled ? MommyTheme.hotPink : .secondary
                            )
                            .frame(width: 34, height: 34)
                            .background(Color.white.opacity(0.07))
                            .clipShape(Circle())

                        VStack(alignment: .leading, spacing: 5) {
                            Text(consequence.title)
                                .font(.headline.weight(.black))
                            Text(consequence.detail)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()
                        Toggle("", isOn: $consequence.isEnabled)
                            .labelsHidden()
                    }
                    .mommyCard()
                    .opacity(consequence.isEnabled ? 1 : 0.55)
                }

                Text("\(state.enabledConsequences.count) punishments pre-authorized")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)

                MommyButton(
                    title: "I consent to these consequences",
                    icon: "checkmark.shield.fill",
                    disabled: state.enabledConsequences.count < 2
                ) {
                    state.requestBeforeEvidence()
                }
            }
        }
    }
}

struct EvidenceView: View {
    enum Kind {
        case before
        case after
    }

    @EnvironmentObject private var state: AppState
    let kind: Kind

    private var image: UIImage? {
        kind == .before ? state.commitment.beforeImage : state.commitment.afterImage
    }

    var body: some View {
        ScreenContainer {
            VStack(spacing: 24) {
                Eyebrow(text: kind == .before ? "Step 3 of 3" : "Time’s up")
                Text(kind == .before ? "Before picture." : "Show me.")
                    .font(.system(size: 42, weight: .black, design: .rounded))
                Text(kind == .before
                    ? "I wasn’t born yesterday."
                    : "Take the after photo from roughly the same angle.")
                    .font(.title3.weight(.medium))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                if kind == .after {
                    HStack(spacing: 13) {
                        Image(systemName: "hourglass.bottomhalf.filled")
                            .font(.title2)
                            .foregroundStyle(
                                state.evidenceSecondsRemaining <= 60
                                    ? MommyTheme.angryRed
                                    : MommyTheme.hotPink
                            )
                        VStack(alignment: .leading, spacing: 3) {
                            Text("EVIDENCE WINDOW")
                                .font(.caption.weight(.black))
                                .tracking(1.2)
                                .foregroundStyle(.secondary)
                            Text("Submit before Mommy assumes the worst.")
                                .font(.subheadline.weight(.semibold))
                        }
                        Spacer()
                        Text(evidenceCountdownText)
                            .font(.title2.weight(.black))
                            .monospacedDigit()
                            .foregroundStyle(
                                state.evidenceSecondsRemaining <= 60
                                    ? MommyTheme.angryRed
                                    : MommyTheme.cream
                            )
                    }
                    .mommyCard()
                }

                PhotoPickerCard(
                    title: kind == .before ? "Document the mess" : "Document your work",
                    subtitle: "Tap to choose a photo",
                    image: image
                ) { selected in
                    if kind == .before {
                        state.setBeforeImage(selected)
                    } else {
                        state.setAfterImage(selected)
                    }
                }

                Label(
                    "Photos are resized and stripped of original metadata before upload.",
                    systemImage: "lock.shield.fill"
                )
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

                MommyButton(
                    title: kind == .before ? "Start the clock" : "Submit to Mommy",
                    icon: kind == .before ? "timer" : "sparkles",
                    disabled: image == nil
                ) {
                    if kind == .before {
                        state.startCountdown()
                    } else {
                        state.verifyEvidence()
                    }
                }
            }
        }
    }

    private var evidenceCountdownText: String {
        let minutes = state.evidenceSecondsRemaining / 60
        let seconds = state.evidenceSecondsRemaining % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

struct DeadlineView: View {
    @EnvironmentObject private var state: AppState

    var body: some View {
        VStack(spacing: 34) {
            Eyebrow(text: "Mommy is watching")
            Text(state.commitment.taskDescription)
                .font(.title2.weight(.black))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 30)

            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.09), lineWidth: 18)
                Circle()
                    .trim(
                        from: 0,
                        to: CGFloat(state.secondsRemaining) /
                            CGFloat(max(state.commitment.deadlineSeconds, 1))
                    )
                    .stroke(
                        MommyTheme.hotPink,
                        style: StrokeStyle(lineWidth: 18, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 0.8), value: state.secondsRemaining)

                VStack(spacing: 2) {
                    Text(countdownText)
                        .font(.system(
                            size: state.commitment.deadlineSeconds >= 3_600 ? 45 : 64,
                            weight: .black,
                            design: .rounded
                        ))
                        .monospacedDigit()
                    Text("TIME REMAINING")
                        .font(.caption.weight(.black))
                        .tracking(2)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 260, height: 260)

            Text("Go. Clean. This is not a documentary.")
                .font(.headline)
                .foregroundStyle(.secondary)
        }
        .padding(24)
    }

    private var countdownText: String {
        let hours = state.secondsRemaining / 3_600
        let minutes = (state.secondsRemaining % 3_600) / 60
        let seconds = state.secondsRemaining % 60
        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

struct VerificationView: View {
    @State private var pulse = false

    var body: some View {
        VStack(spacing: 28) {
            ZStack {
                Circle()
                    .fill(MommyTheme.hotPink.opacity(0.18))
                    .frame(width: pulse ? 210 : 160, height: pulse ? 210 : 160)
                Image(systemName: "eyes")
                    .font(.system(size: 72, weight: .bold))
                    .foregroundStyle(MommyTheme.hotPink)
            }
            .animation(
                .easeInOut(duration: 1).repeatForever(autoreverses: true),
                value: pulse
            )

            Eyebrow(text: "Analyzing evidence")
            Text("Mommy is\ncomparing photos…")
                .font(.system(size: 38, weight: .black, design: .rounded))
                .multilineTextAlignment(.center)
            Text("Looking for substantial completion,\nnot creative camera angles.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(24)
        .onAppear { pulse = true }
    }
}

struct SuccessView: View {
    @EnvironmentObject private var state: AppState

    var body: some View {
        VStack(spacing: 24) {
            Text("😌")
                .font(.system(size: 96))
            Eyebrow(text: "Acceptable", color: MommyTheme.mint)
            Text("Fine. You did it.")
                .font(.system(size: 42, weight: .black, design: .rounded))
                .multilineTextAlignment(.center)
            Text(state.verification?.reason ?? "The task appears complete.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            MommyButton(title: "Return home", icon: "house.fill", color: MommyTheme.mint) {
                state.reset()
            }
        }
        .padding(24)
    }
}

struct FailureView: View {
    @EnvironmentObject private var state: AppState

    var body: some View {
        ScreenContainer {
            VStack(spacing: 22) {
                Text("🚨")
                    .font(.system(size: 78))
                Eyebrow(text: "Evidence rejected", color: MommyTheme.angryRed)
                Text("ABSOLUTELY\nNOT")
                    .font(.system(size: 50, weight: .black, design: .rounded))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(MommyTheme.angryRed)

                VStack(spacing: 12) {
                    Text("“\(state.verification?.roast ?? "Nice try. Mommy has eyes.")”")
                        .font(.title3.weight(.black))
                        .multilineTextAlignment(.center)
                    Divider().overlay(Color.white.opacity(0.12))
                    Text(state.verification?.reason ?? "")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    Text("\(Int((state.verification?.confidence ?? 0) * 100))% confidence")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(MommyTheme.angryRed)
                }
                .mommyCard()

                VStack(spacing: 6) {
                    Text("MOMMY COURT")
                        .font(.title2.weight(.black))
                    Text("Five jurors. One minute. No appeals.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                MommyButton(
                    title: "Summon Mommy Court",
                    icon: "building.columns.fill",
                    color: MommyTheme.angryRed
                ) {
                    state.startCourt()
                }
            }
        }
    }
}

struct CourtView: View {
    @EnvironmentObject private var state: AppState

    var body: some View {
        ScreenContainer {
            VStack(spacing: 18) {
                Eyebrow(text: "Live", color: MommyTheme.angryRed)
                Text("MOMMY COURT")
                    .font(.system(size: 39, weight: .black, design: .rounded))

                if state.isPreparingCourt {
                    ProgressView()
                        .controlSize(.large)
                        .padding(.top, 70)
                    Text("Calling the internet parents…")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                } else {
                    countdownHeader

                    HStack(spacing: 16) {
                        Image(systemName: "dot.radiowaves.left.and.right")
                            .font(.system(size: 34, weight: .bold))
                            .foregroundStyle(MommyTheme.mint)
                            .frame(width: 62, height: 62)
                            .background(MommyTheme.mint.opacity(0.1))
                            .clipShape(Circle())

                        VStack(alignment: .leading, spacing: 6) {
                            Text("JURY DEVICES SYNCED")
                                .font(.caption.weight(.black))
                                .tracking(1.3)
                                .foregroundStyle(MommyTheme.mint)
                            Text("The open voting page receives this case automatically.")
                                .font(.subheadline.weight(.semibold))
                            if !AppConfig.isSupabaseConfigured {
                                Text("Demo mode: sample human votes arrive automatically.")
                                    .font(.caption)
                                    .foregroundStyle(.orange)
                            }
                        }
                    }
                    .mommyCard()

                    jurySeats
                    deliberations
                    liveTally
                }
            }
        }
    }

    private var countdownHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("VOTING CLOSES IN")
                    .font(.caption.weight(.black))
                    .foregroundStyle(.secondary)
                Text(state.courtSecondsRemaining == 0 ? "TALLYING…" : "Choose wisely.")
                    .font(.headline.weight(.black))
            }
            Spacer()
            Text("\(state.courtSecondsRemaining)")
                .font(.system(size: 48, weight: .black, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(
                    state.courtSecondsRemaining <= 5
                        ? MommyTheme.angryRed
                        : MommyTheme.cream
                )
        }
        .mommyCard()
    }

    private var jurySeats: some View {
        VStack(spacing: 8) {
            VotePill(
                label: "Friend 1",
                state: seatState(requiredHumanVotes: 1),
                color: seatColor(requiredHumanVotes: 1)
            )
            VotePill(
                label: "Friend 2",
                state: seatState(requiredHumanVotes: 2),
                color: seatColor(requiredHumanVotes: 2)
            )
            ForEach(["Tiger Mom", "Corporate Mom", "Gentle Mom"], id: \.self) { persona in
                VotePill(
                    label: persona,
                    state: state.courtSecondsRemaining == 0 ? "VOTED" : "DELIBERATING",
                    color: state.courtSecondsRemaining == 0 ? MommyTheme.mint : MommyTheme.hotPink
                )
            }
        }
    }

    private func seatState(requiredHumanVotes: Int) -> String {
        if state.humanVotes.count >= requiredHumanVotes {
            return "VOTED"
        }
        return state.courtSecondsRemaining == 0 ? "AI FILLED" : "WAITING"
    }

    private func seatColor(requiredHumanVotes: Int) -> Color {
        state.humanVotes.count >= requiredHumanVotes || state.courtSecondsRemaining == 0
            ? MommyTheme.mint
            : .orange
    }

    private var liveTally: some View {
        VStack(spacing: 10) {
            ForEach(state.enabledConsequences) { consequence in
                HStack {
                    Image(systemName: consequence.type.icon)
                        .foregroundStyle(MommyTheme.hotPink)
                        .frame(width: 24)
                    Text(consequence.title)
                        .font(.caption.weight(.bold))
                        .lineLimit(1)
                    Spacer()
                    Text("\(voteCount(for: consequence.id))")
                        .font(.headline.weight(.black))
                        .monospacedDigit()
                }
            }
        }
        .mommyCard()
    }

    @ViewBuilder
    private var deliberations: some View {
        if !visibleDeliberations.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("🔓 LEAKED DELIBERATIONS")
                        .font(.caption.weight(.black))
                        .tracking(1.2)
                        .foregroundStyle(MommyTheme.hotPink)
                    Spacer()
                    Text("CONFIDENTIAL")
                        .font(.system(size: 9, weight: .black))
                        .foregroundStyle(.secondary)
                }

                ForEach(visibleDeliberations) { vote in
                    HStack(alignment: .top, spacing: 11) {
                        Text(personaEmoji(vote.persona))
                            .font(.title2)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(vote.persona)
                                .font(.caption.weight(.black))
                                .foregroundStyle(MommyTheme.cream)
                            Text("“\(vote.comment)”")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(13)
                    .background(Color.white.opacity(0.045))
                    .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .mommyCard()
            .animation(.spring(response: 0.45, dampingFraction: 0.8), value: visibleDeliberations.count)
        }
    }

    private var visibleDeliberations: [AIVote] {
        let visibleCount: Int
        switch state.courtSecondsRemaining {
        case 51...:
            visibleCount = 0
        case 41...50:
            visibleCount = 1
        case 31...40:
            visibleCount = 2
        default:
            visibleCount = 3
        }

        let personaOrder = ["Tiger Mom", "Corporate Mom", "Gentle Mom"]
        return Array(
            state.aiVotes
                .sorted {
                    (personaOrder.firstIndex(of: $0.persona) ?? 99) <
                        (personaOrder.firstIndex(of: $1.persona) ?? 99)
                }
                .prefix(visibleCount)
        )
    }

    private func personaEmoji(_ persona: String) -> String {
        switch persona {
        case "Tiger Mom": "🐯"
        case "Corporate Mom": "📊"
        case "Gentle Mom": "🌸"
        default: "👩🏻"
        }
    }

    private func voteCount(for consequenceID: UUID) -> Int {
        state.votes.filter { $0.consequenceID == consequenceID }.count
    }
}

struct VerdictView: View {
    @EnvironmentObject private var state: AppState
    @State private var reveal = false

    var body: some View {
        ScreenContainer {
            VStack(spacing: 22) {
                Text("⚖️")
                    .font(.system(size: 74))
                    .scaleEffect(reveal ? 1 : 0.2)
                    .rotationEffect(.degrees(reveal ? 0 : -18))

                Eyebrow(text: "The internet has spoken")
                Text(state.winningConsequence?.title.uppercased() ?? "GUILTY")
                    .font(.system(size: 42, weight: .black, design: .rounded))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(MommyTheme.cream)

                if let winner = state.winningConsequence {
                    verdictCard(winner)
                }

                VStack(alignment: .leading, spacing: 12) {
                    ForEach(state.enabledConsequences) { consequence in
                        let count = state.votes.filter {
                            $0.consequenceID == consequence.id
                        }.count
                        HStack {
                            Text(consequence.title)
                                .font(.caption.weight(.bold))
                                .frame(width: 130, alignment: .leading)
                                .lineLimit(1)
                            GeometryReader { proxy in
                                RoundedRectangle(cornerRadius: 5)
                                    .fill(
                                        consequence.id == state.winningConsequence?.id
                                            ? MommyTheme.hotPink
                                            : Color.white.opacity(0.18)
                                    )
                                    .frame(
                                        width: max(
                                            8,
                                            proxy.size.width * CGFloat(count) /
                                                CGFloat(max(state.votes.count, 1))
                                        )
                                    )
                            }
                            .frame(height: 10)
                            Text("\(count)")
                                .font(.headline.weight(.black))
                                .frame(width: 18)
                        }
                    }
                }
                .mommyCard()

                if let decisiveVote = state.votes.first(where: {
                    $0.voterKind == "ai"
                        && $0.consequenceID == state.winningConsequence?.id
                        && $0.comment != nil
                }),
                   let comment = decisiveVote.comment,
                   let persona = decisiveVote.persona {
                    Text("“\(comment)”\n— \(persona)")
                        .font(.subheadline.weight(.semibold))
                        .italic()
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                MommyButton(title: "I have learned nothing", icon: "arrow.counterclockwise") {
                    state.reset()
                }
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.7, dampingFraction: 0.58)) {
                reveal = true
            }
        }
    }

    @ViewBuilder
    private func verdictCard(_ consequence: Consequence) -> some View {
        VStack(spacing: 12) {
            Image(systemName: consequence.type.icon)
                .font(.system(size: 42))
                .foregroundStyle(MommyTheme.hotPink)

            switch consequence.type {
            case .grounded:
                Text("PHONE BRICKED")
                    .font(.title3.weight(.black))
                Text("Non-essential apps blocked for 2 hours\nPhone, Messages, and Maps still work")
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            case .orders:
                Text("MOMMY EXPECTS EVIDENCE")
                    .font(.title3.weight(.black))
                Text("A new proof-required task has been assigned.")
                    .foregroundStyle(.secondary)
            case .embarrass:
                Text("SEND QUEUED")
                    .font(.title3.weight(.black))
                Text("Pre-approved spicy pic to \(consequence.payload["recipient"] ?? "approved recipient")")
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            case .wasteMoney:
                Text("ORDER PLACED")
                    .font(.title3.weight(.black))
                Text("36-pack adult diapers\n$17.99 of $20 punishment budget used")
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .mommyCard()
        .overlay {
            RoundedRectangle(cornerRadius: 22)
                .stroke(MommyTheme.hotPink.opacity(0.7), lineWidth: 2)
        }
    }
}
