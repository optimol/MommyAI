# AI Mommy

Hackathon prototype. Optimize for shipping a polished demo quickly.

## Repo

- ios/: SwiftUI iPhone app
- backend/: Supabase migrations/functions
- web/jury/: mobile-friendly voting site

## Architecture

The primary demo flow is:

commitment
→ before evidence
→ deadline
→ after evidence
→ AI verification
→ failure
→ 60-second Mommy Court
→ human + AI votes
→ verdict
→ consequence

## Rules

- Prefer simple implementations.
- No authentication unless required.
- Use Supabase.
- Voting must work from external browser devices.
- The iOS app owns the primary experience.
- Never add functionality outside the current task without asking.
- Keep backend schemas minimal.
- Build/test after meaningful changes.
- Never commit secrets.
- Mock real purchases and message sending.
- Consequences must come only from options pre-authorized by the user.

## Hackathon priorities

1. Working vertical demo
2. Reliability
3. Comedy/polish
4. Real voting
5. Screen Time integration
6. Everything else
