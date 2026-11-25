import Foundation

/// Fast, relevance-ranked search engine for ClearDesk (exact, prefix, word-boundary,
/// multi-word token, fuzzy subsequence, and parent-folder matching).
public enum SearchEngine {
    public static func search(_ query: String, in items: [DeskItem]) -> [DeskItem] {
        let normalizedQuery = normalize(query).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedQuery.isEmpty else {
            return items
        }

        let tokens = normalizedQuery
            .split(whereSeparator: { $0.isWhitespace })
            .map(String.init)
            .filter { !$0.isEmpty }

        guard !tokens.isEmpty else {
            return items
        }

        let scored: [(item: DeskItem, score: Int)] = items.compactMap { item in
            guard let score = score(item: item, fullQuery: normalizedQuery, tokens: tokens) else {
                return nil
            }
            return (item, score)
        }

        return scored
            .sorted { lhs, rhs in
                if lhs.score != rhs.score {
                    return lhs.score > rhs.score
                }
                if lhs.item.modifiedAt != rhs.item.modifiedAt {
                    return lhs.item.modifiedAt > rhs.item.modifiedAt
                }
                return lhs.item.name.localizedCaseInsensitiveCompare(rhs.item.name) == .orderedAscending
            }
            .map(\.item)
    }

    private static func score(item: DeskItem, fullQuery: String, tokens: [String]) -> Int? {
        let name = normalize(item.name)
        let stem = normalize((item.name as NSString).deletingPathExtension)
        let parent = item.relativeParentPath.map(normalize) ?? ""
        let combined = parent.isEmpty ? name : "\(parent)/\(name)"

        let topLevelBonus = item.relativeParentPath == nil ? 25 : 0
        let desktopBonus = item.location == .desktop ? 10 : 0

        // 1. Exact match on filename or stem
        if name == fullQuery || stem == fullQuery {
            return 1000 + topLevelBonus + desktopBonus
        }

        // 2. Prefix match on filename
        if name.hasPrefix(fullQuery) {
            return 800 + topLevelBonus + desktopBonus
        }

        // 3. Word-boundary match in filename (e.g., "roadmap" in "Q4_Product_Roadmap.pdf")
        let nameWords = splitWords(name)
        if nameWords.contains(where: { $0.hasPrefix(fullQuery) }) {
            return 650 + topLevelBonus + desktopBonus
        }

        // 4. Direct substring match in filename
        if name.contains(fullQuery) {
            return 500 + topLevelBonus + desktopBonus
        }

        // 5. Multi-word token match (all tokens present in filename, any order)
        if tokens.count > 1 && tokens.allSatisfy({ name.contains($0) }) {
            let wordHits = tokens.filter { token in nameWords.contains(where: { $0.hasPrefix(token) }) }.count
            return 420 + (wordHits * 20) + topLevelBonus + desktopBonus
        }

        // 6. Fuzzy subsequence match on filename (e.g., "q4rm" -> "Q4_Roadmap.pdf")
        if fullQuery.count >= 2 && isSubsequence(fullQuery, of: name) {
            return 280 + topLevelBonus + desktopBonus
        }

        // 7. Match across parent folder + filename (e.g., "taxes w2" -> "Taxes 2025/W2.pdf")
        if tokens.allSatisfy({ combined.contains($0) }) {
            return 200 + desktopBonus
        }

        return nil
    }

    private static func normalize(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
    }

    private static func splitWords(_ text: String) -> [String] {
        text.components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
    }

    private static func isSubsequence(_ needle: String, of haystack: String) -> Bool {
        var needleIdx = needle.startIndex
        var hayIdx = haystack.startIndex

        while needleIdx < needle.endIndex && hayIdx < haystack.endIndex {
            if needle[needleIdx] == haystack[hayIdx] {
                needleIdx = needle.index(after: needleIdx)
            }
            hayIdx = haystack.index(after: hayIdx)
        }
        return needleIdx == needle.endIndex
    }
}
