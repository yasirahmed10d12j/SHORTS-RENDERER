import Foundation

// MARK: - Types

struct StoryScene: Codable, Identifiable, Equatable {
    let n: Int
    let narration: String
    let visual: String?
    var id: Int { n }
}

/// One built-in story from the app's 100-story collection.
struct BuiltInStory: Codable, Identifiable, Comparable, Equatable {
    let id: String
    let title: String
    let logline: String?
    let scenes: [StoryScene]
    
    static func < (lhs: BuiltInStory, rhs: BuiltInStory) -> Bool {
        lhs.title < rhs.title
    }
    
    /// Rough estimate of total voice duration (~4 chars/sec average speech rate).
    var estimatedDuration: Double {
        let totalChars = scenes.map(\.narration).joined().count
        return Double(totalChars) / 4.0
    }
    
    /// Converts to StoryScript for compatibility with existing render pipeline.
    var storyScript: StoryScript {
        StoryScript(
            title: title,
            logline: logline,
            scenes: scenes.map { s in
                StoryScript.Scene(n: s.n, narration: s.narration, visual: s.visual)
            }
        )
    }
}

// MARK: - Bundle Loading

enum StoryBundleError: Error, LocalizedError {
    case bundleNotFound
    case decodeError(String)
    
    var errorDescription: String? {
        switch self {
        case .bundleNotFound: return "Stories bundle not found."
        case .decodeError(let msg): return "Failed to parse stories: \(msg)"
        }
    }
}

enum StoryBundle {
    /// Load all built-in stories from embedded JSON bundle.
    static func load() throws -> [BuiltInStory] {
        guard let url = Bundle.main.url(forResource: "stories", withExtension: "json") else {
            throw StoryBundleError.bundleNotFound
        }
        let data = try Data(contentsOf: url)
        let decoded = try JSONDecoder().decode([BuiltInStory].self, from: data)
        return decoded.sorted()
    }
    
    /// Get cached stories (loads on first call).
    static var stories: [BuiltInStory]? {
        cache ?? {
            do {
                cache = try load()
            } catch {
                print("Warning: Could not load story bundle: \(error)")
            }
            return cache
        }()
    }
    
    private static var cache: [BuiltInStory]? = nil
}

// MARK: - Story Categories (for filtering)

enum StoryCategory: String, CaseIterable, Identifiable {
    case fairyTales = "Fairy Tales"
    case funnyAnimals = "Funny Animals"
    case moralStories = "Moral Stories"
    case adventure = "Adventure"
    case modernTales = "Modern Tales"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .fairyTales: return "sparkles"
        case .funnyAnimals: return "person.fill"
        case .moralStories: return "lightbulb.fill"
        case .adventure: return "map.fill"
        case .modernTales: return "star.fill"
        }
    }
}

extension BuiltInStory {
    /// Assign a category based on keywords in the title.
    var category: StoryCategory? {
        let t = title.lowercased()
        if ["king", "queen", "prince", "princess", "castle", "fairy", "magic", "beanstalk", "rumple"].any(where: t.contains) {
            return .fairyTales
        }
        if ["lion", "hare", "tortoise", "fox", "crow", "ant", "grasshopper", "mouse", "cat", "wolf", "goose", "pig", "duck", "bear"].any(where: t.contains) {
            return .funnyAnimals
        }
        if ["honest", "boy-who-cried", "greedy", "lazy", "bell", "winter", "woodcutter"].any(where: t.contains) {
            return .moralStories
        }
        if ["climb", "giant", "treasure", "quest", "adventure"].any(where: t.contains) {
            return .adventure
        }
        return .modernTales
    }
}

// Helper extension
extension Array where Element == String {
    func any(where predicate: (String) -> Bool) -> Bool {
        contains(predicate)
    }
}
