import Foundation

public enum WindowMatcher {
    /// Returns pairs of stored-window index and current-window index.
    public static func match(
        stored: [WindowSnapshot],
        current: [WindowSnapshot]
    ) -> [(stored: Int, current: Int)] {
        var result: [(stored: Int, current: Int)] = []
        var unmatchedCurrent = Set(current.indices)

        for storedIndex in stored.indices {
            let candidate = bestCandidate(
                for: stored[storedIndex],
                in: current,
                candidates: unmatchedCurrent
            )
            if let candidate {
                result.append((storedIndex, candidate))
                unmatchedCurrent.remove(candidate)
            }
        }
        return result
    }

    private static func bestCandidate(
        for stored: WindowSnapshot,
        in current: [WindowSnapshot],
        candidates: Set<Int>
    ) -> Int? {
        let sameApp = candidates.filter {
            current[$0].bundleIdentifier == stored.bundleIdentifier
        }
        guard !sameApp.isEmpty else { return nil }

        return sameApp.max { lhs, rhs in
            score(stored: stored, current: current[lhs])
                < score(stored: stored, current: current[rhs])
        }
    }

    private static func score(stored: WindowSnapshot, current: WindowSnapshot) -> Int {
        var score = 0
        if let identifier = stored.accessibilityIdentifier,
           !identifier.isEmpty,
           identifier == current.accessibilityIdentifier {
            score += 100
        }
        if let title = stored.title,
           !title.isEmpty,
           title == current.title {
            score += 50
        }
        if stored.role == current.role { score += 8 }
        if stored.subrole == current.subrole { score += 8 }
        if stored.indexInApplication == current.indexInApplication { score += 4 }
        return score
    }
}
