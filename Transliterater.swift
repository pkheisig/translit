import Foundation

struct Transliterater {
    private static let defaultMapping: [(String, String)] = [
        ("shch", "щ"),
        ("sch", "щ"),
        ("'e", "ё"),
        ("e'", "э"),
        ("zh", "ж"),
        ("ch", "ч"),
        ("sh", "ш"),
        ("kh", "х"),
        ("ts", "ц"),
        ("yu", "ю"),
        ("ya", "я"),
        ("ju", "ю"),
        ("ja", "я"),
        ("eh", "э"),
        ("a", "а"),
        ("b", "б"),
        ("v", "в"),
        ("g", "г"),
        ("d", "д"),
        ("e", "е"),
        ("z", "з"),
        ("i", "и"),
        ("j", "й"),
        ("k", "к"),
        ("l", "л"),
        ("m", "м"),
        ("n", "н"),
        ("o", "о"),
        ("p", "п"),
        ("r", "р"),
        ("s", "с"),
        ("t", "т"),
        ("u", "у"),
        ("f", "ф"),
        ("y", "ы"),
        ("'", "ь"),
        ("''", "ъ")
    ]
    
    // Stores the mapping in User Preference order (priority for same-length keys)
    private static var _mapping: [(String, String)]?
    
    // Caches the mapping sorted by length (descending) for the engine
    private static var _sortedMapping: [(String, String)]?
    
    // Public interface for UI (Raw user order)
    static var mapping: [(String, String)] {
        if let m = _mapping { return m }
        load()
        return _mapping ?? defaultMapping
    }
    
    // Internal interface for Engine (Sorted by length, then user order)
    private static var activeMapping: [(String, String)] {
        if let sm = _sortedMapping { return sm }
        
        // Stable sort: Longest keys first.
        // For equal lengths, original (user) order is preserved.
        let sorted = mapping.sorted { $0.0.count > $1.0.count }
        _sortedMapping = sorted
        return sorted
    }

    private static func load() {
        if let saved = UserDefaults.standard.array(forKey: "savedMapping") as? [[String: String]] {
            var newMap: [(String, String)] = []
            for dict in saved {
                // Use empty string as fallback to ensure we don't crash, though validation happens in UI
                let l = dict["l"] ?? ""
                let c = dict["c"] ?? ""
                newMap.append((l, c))
            }
            _mapping = newMap
        } else {
            _mapping = defaultMapping
        }
        _sortedMapping = nil
    }
    
    static func save(newMapping: [(String, String)]) {
        // Save exactly as provided (user order)
        _mapping = newMapping
        _sortedMapping = nil // Invalidate cache
        
        let toSave = newMapping.map { ["l": $0.0, "c": $0.1] }
        UserDefaults.standard.set(toSave, forKey: "savedMapping")
    }
    
    static func resetToDefaults() {
        _mapping = defaultMapping
        _sortedMapping = nil
        UserDefaults.standard.removeObject(forKey: "savedMapping")
    }

    static func transliterate(_ input: String) -> String {
        var result = ""
        var remaining = input
        
        // Use the length-sorted mapping
        let currentMapping = activeMapping
        
        while !remaining.isEmpty {
            var matched = false
            
            // Try matching longest sequences first (case insensitive)
            for (latin, cyrillic) in currentMapping {
                if latin.isEmpty { continue } // Skip empty keys
                
                if remaining.lowercased().hasPrefix(latin) {
                    let isUppercase = remaining.first?.isUppercase ?? false
                    result += isUppercase ? cyrillic.uppercased() : cyrillic
                    remaining.removeFirst(latin.count)
                    matched = true
                    break
                }
            }
            
            if !matched {
                result += String(remaining.removeFirst())
            }
        }
        
        return result
    }
}
