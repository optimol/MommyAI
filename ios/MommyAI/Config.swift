import Foundation

enum AppConfig {
    // Supabase publishable keys are safe to ship in a client when RLS is enabled.
    // Never place a service-role key or an AI provider key in this app.
    static let supabaseURL = "https://YOUR_PROJECT.supabase.co"
    static let supabasePublishableKey = "YOUR_SUPABASE_PUBLISHABLE_KEY"

    static var isSupabaseConfigured: Bool {
        !supabaseURL.contains("YOUR_PROJECT")
            && !supabasePublishableKey.contains("YOUR_SUPABASE")
    }
}
