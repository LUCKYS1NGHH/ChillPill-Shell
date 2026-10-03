pragma Singleton
import Quickshell
import QtQuick

// Matchers behind the fuzzy search toggles in the app launcher and the
// clipboard manager. Both share the scoring, each keeps its own ranking.
Singleton {
    id: root

    // How tight a match is, ignoring where in the text it lands: the extra
    // characters its window holds cost, query letters sitting next to each
    // other pay, and so does whatever trails the window ("btop -b -o 0.5" is a
    // weaker match for tpob than plain "btop"). Deliberately not tier-based - a
    // long entry contains any short query in order, so "in order first" would
    // rank "Meeting at 3pm" above "btop". Callers add their own tiers on top.
    function quality(positions, hayLength) {
        const sorted = positions.slice().sort((a, b) => a - b)
        const window = sorted[sorted.length - 1] - sorted[0] + 1
        let adjacent = 0
        for (let k = 1; k < sorted.length; k++) {
            if (sorted[k] === sorted[k - 1] + 1) adjacent++
        }
        const tail = Math.max(0, (hayLength || window) - window)
        return adjacent * 4 - (window - positions.length) * 2 - tail * 0.5
    }

    // cheap reject, so a missing character doesn't turn into a full scan
    function containsAll(needle, hay) {
        const missing = {}
        for (let n = 0; n < needle.length; n++) missing[needle[n]] = true
        for (let h = 0; h < hay.length; h++) delete missing[hay[h]]
        for (const c in missing) return false
        return true
    }

    // tightest window holding the query in order, not necessarily adjacent.
    // positions or null
    function ordered(needle, hay) {
        if (needle.length === 0 || needle.length > hay.length) return null
        if (!root.containsAll(needle, hay)) return null
        let best = null
        let bestSpan = Infinity
        for (let s = 0; s < hay.length; s++) {
            if (hay[s] !== needle[0]) continue
            const pos = [s]
            let end = s
            let at = s + 1
            let ok = true
            for (let n = 1; n < needle.length; n++) {
                let found = -1
                while (at < hay.length) {
                    if (hay[at] === needle[n]) { found = at; break }
                    at++
                }
                // a window this long already loses to the best one
                if (found < 0 || found - s + 1 >= bestSpan) { ok = false; break }
                pos.push(found)
                end = found
                at = found + 1
            }
            if (!ok) continue
            const span = end - s + 1
            if (span < bestSpan) {
                best = pos
                bestSpan = span
                if (bestSpan === needle.length) break
            }
        }
        return best
    }

    // tightest window holding the same letters in any order ("tpob" -> btop).
    // minimum-window-substring with per letter counts, then the positions that
    // satisfy them. positions or null
    function scattered(needle, hay) {
        if (needle.length === 0 || needle.length > hay.length) return null
        const need = {}
        for (let n = 0; n < needle.length; n++) {
            need[needle[n]] = (need[needle[n]] || 0) + 1
        }
        let missing = needle.length
        let left = 0
        let bestSpan = Infinity
        let start = 0
        let end = 0
        for (let right = 0; right < hay.length; right++) {
            const c = hay[right]
            if (need[c] !== undefined) {
                need[c]--
                if (need[c] >= 0) missing--
            }
            if (missing === 0) {
                // shrink while the window still holds every letter
                while (missing === 0 && left <= right) {
                    if (right - left + 1 < bestSpan) {
                        bestSpan = right - left + 1
                        start = left
                        end = right
                    }
                    const d = hay[left]
                    if (need[d] !== undefined) {
                        need[d]++
                        if (need[d] > 0) missing++
                    }
                    left++
                    if (bestSpan === needle.length) { right = hay.length; break }
                }
            }
        }
        if (bestSpan === Infinity) return null

        // hand back which characters were used, first copies inside the window
        const want = {}
        for (let n = 0; n < needle.length; n++) {
            want[needle[n]] = (want[needle[n]] || 0) + 1
        }
        const pos = []
        for (let i = start; i <= end && pos.length < needle.length; i++) {
            if (want[hay[i]] > 0) { want[hay[i]]--; pos.push(i) }
        }
        return pos
    }

    // the tighter of the two. any order needs 3+ chars, two loose letters
    // match most of the list
    function best(needle, hay) {
        let positions = root.ordered(needle, hay)
        if (needle.length >= 3) {
            const loose = root.scattered(needle, hay)
            if (loose && (positions === null
                || root.quality(loose, hay.length) > root.quality(positions, hay.length)))
                positions = loose
        }
        if (positions === null) return null
        return { score: root.quality(positions, hay.length), positions: positions }
    }

    function esc(s) { return s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;") }

    // wrap the given indices in <b> tags, for Text.StyledText
    function highlight(s, positions) {
        if (!positions || positions.length === 0) return root.esc(s)
        let out = ""
        let bold = false
        for (let i = 0; i <= s.length; i++) {
            const hit = i < s.length && positions.indexOf(i) >= 0
            if (hit && !bold) { out += "<b>"; bold = true }
            else if (!hit && bold) { out += "</b>"; bold = false }
            if (i < s.length) out += root.esc(s[i])
        }
        return out
    }
}
