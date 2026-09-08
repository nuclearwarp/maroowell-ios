import Foundation

enum AppConfig {
    static var supabaseURL: URL {
        guard
            let value = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") as? String,
            let url = URL(string: value)
        else {
            preconditionFailure("SUPABASE_URL is missing from Info.plist")
        }
        return url
    }

    static var supabasePublishableKey: String {
        guard
            let value = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_PUBLISHABLE_KEY") as? String,
            !value.isEmpty
        else {
            preconditionFailure("SUPABASE_PUBLISHABLE_KEY is missing from Info.plist")
        }
        return value
    }
}
