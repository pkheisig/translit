import Foundation

struct Transliterater {
    static let mapping: [(String, String)] = [
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

    static func transliterate(_ input: String) -> String {
        var result = ""
        var remaining = input
        
        while !remaining.isEmpty {
            var matched = false
            
            // Try matching longest sequences first (case insensitive)
            for (latin, cyrillic) in mapping {
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
