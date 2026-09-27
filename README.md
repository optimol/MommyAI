Disclaimer: Mostly unreviewed AI code

# AI Mommy

A hackathon-ready accountability demo:

**Commit → prove it → fail → Mommy Court votes → suffer a pre-authorized consequence.**

## What is implemented

- SwiftUI iPhone app with the complete 90-second demo flow
- Camera and photo-library before/after evidence
- Cloud multimodal verification through a Supabase Edge Function
- 60-second five-seat Mommy Court with automatic jury-page sync
- Real browser votes from the Mac and iPad
- Three AI jurors generated in one model request
- Animated verdict and presentation-ready punishment execution
- A credential-free fallback that runs the full staged demo locally

External purchases, messages, and Screen Time changes remain disabled.

## Run the local fallback

Open `ios/MommyAI.xcodeproj` in Xcode and run the `MommyAI` scheme.

No credentials are required. Evidence receives a deterministic failure verdict, and two sample human votes arrive during court. This is the safest presentation backup.

## Connect Supabase

1. Create a Supabase project and note its project ref, project URL, and publishable key.
2. From `backend/`, deploy the schema and functions:

   ```sh
   npx supabase@latest db push --project-ref YOUR_PROJECT_REF
   npx supabase@latest secrets set OPENAI_API_KEY=YOUR_KEY --project-ref YOUR_PROJECT_REF
   npx supabase@latest functions deploy --project-ref YOUR_PROJECT_REF --use-api
   ```

3. Set the project URL and publishable key in `ios/MommyAI/Config.swift`.
4. Prepare the jury web app:

   ```sh
   cd web/jury
   cp .env.example .env
   npm install
   npm run dev
   ```

5. Add the same Supabase URL and publishable key to `web/jury/.env`.
6. Open the base jury page on the Mac and iPad. Use either a deployed HTTPS URL
   or the Mac's LAN address, such as `http://192.168.1.20:5173`.

The base jury URL is a live lobby. Leave it open on the Mac and iPad; the newest
open case appears automatically through Supabase Realtime.

Only the Supabase publishable key belongs in the clients. Keep the OpenAI key in Supabase secrets; never add it to the iOS or web app.

## Demo rehearsal

1. Open the jury URL on the Mac and iPad once to verify network access.
2. Run the commitment with a 1-minute deadline.
3. Submit intentionally inadequate after evidence.
4. Watch the case appear automatically, then cast one vote from each device.
5. Let the timer reach zero; the three AI Moms fill the remaining seats.

The web page uses Supabase Realtime for case updates. The iPhone polls votes once per second for a simple, reliable stage display.
