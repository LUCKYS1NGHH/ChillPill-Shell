pragma Singleton
import Quickshell
import QtQuick

// Tiny expression evaluator behind the launcher's "=" mode.
// Recursive descent over numbers, + - * / % ^, parentheses, unary signs, a
// handful of functions and two constants. Deliberately no eval(): the query is
// raw user input, so it only ever reaches this parser.
Singleton {
    id: root

    readonly property var fns: ({
        sqrt: Math.sqrt, abs: Math.abs, round: Math.round, floor: Math.floor,
        ceil: Math.ceil, min: Math.min, max: Math.max, pow: Math.pow,
        log: Math.log, exp: Math.exp, sin: Math.sin, cos: Math.cos, tan: Math.tan
    })
    readonly property var consts: ({ pi: Math.PI, e: Math.E })

    // returns { ok, text, value } on success or { ok: false, error } on failure
    function evaluate(input) {
        const s = String(input).trim()
        if (s === "") return { ok: false, empty: true, error: "" }
        let i = 0

        function fail(msg) { throw new Error(msg) }
        function ws() { while (i < s.length && s[i] === " ") i++ }

        function parseExpr() {
            let v = parseTerm()
            for (;;) {
                ws()
                const c = s[i]
                if (c === "+") { i++; v += parseTerm() }
                else if (c === "-") { i++; v -= parseTerm() }
                else return v
            }
        }

        function parseTerm() {
            let v = parseUnary()
            for (;;) {
                ws()
                const c = s[i]
                if (c === "*" || c === "/" || c === "%") {
                    i++
                    const r = parseUnary()
                    if (c === "*") { v *= r }
                    else {
                        if (r === 0) fail("division by zero")
                        v = c === "/" ? v / r : v % r
                    }
                } else return v
            }
        }

        function parseUnary() {
            ws()
            if (s[i] === "-") { i++; return -parseUnary() }
            if (s[i] === "+") { i++; return parseUnary() }
            return parsePower()
        }

        // right associative, so 2^3^2 is 2^9
        function parsePower() {
            const base = parsePrimary()
            ws()
            if (s[i] === "^") { i++; return Math.pow(base, parseUnary()) }
            return base
        }

        function parsePrimary() {
            ws()
            const c = s[i]
            if (c === undefined) fail("unexpected end of expression")
            if (c === "(") {
                i++
                const v = parseExpr()
                ws()
                if (s[i] !== ")") fail("missing ')'")
                i++
                return v
            }
            if (c >= "0" && c <= "9" || c === ".") return parseNumber()
            if (/[a-z]/i.test(c)) return parseIdent()
            fail("unexpected '" + c + "'")
        }

        function parseNumber() {
            const start = i
            while (i < s.length && (s[i] >= "0" && s[i] <= "9" || s[i] === ".")) i++
            if (s[i] === "e" || s[i] === "E") {
                i++
                if (s[i] === "+" || s[i] === "-") i++
                while (i < s.length && s[i] >= "0" && s[i] <= "9") i++
            }
            const n = Number(s.slice(start, i))
            if (isNaN(n)) fail("bad number")
            return n
        }

        function parseIdent() {
            const start = i
            while (i < s.length && /[a-z0-9_]/i.test(s[i])) i++
            const name = s.slice(start, i).toLowerCase()
            ws()
            if (s[i] === "(") {
                i++
                const args = []
                ws()
                if (s[i] !== ")") {
                    args.push(parseExpr())
                    ws()
                    while (s[i] === ",") { i++; args.push(parseExpr()); ws() }
                }
                if (s[i] !== ")") fail("missing ')'")
                i++
                const fn = root.fns[name]
                if (!fn) fail("unknown function '" + name + "'")
                const out = fn.apply(null, args)
                if (typeof out !== "number" || isNaN(out)) fail(name + "() is undefined")
                return out
            }
            if (root.consts[name] !== undefined) return root.consts[name]
            fail("unknown name '" + name + "'")
        }

        try {
            const v = parseExpr()
            ws()
            if (i < s.length) fail("unexpected '" + s[i] + "'")
            if (typeof v !== "number" || isNaN(v) || !isFinite(v)) fail("undefined")
            return { ok: true, value: v, text: root.fmt(v) }
        } catch (e) {
            return { ok: false, error: e && e.message ? e.message : "invalid expression" }
        }
    }

    // trim float noise: 1/3 -> 0.333333333333, 2+2 -> 4
    function fmt(v) {
        if (Number.isInteger(v)) return String(v)
        return String(Number(v.toPrecision(12)))
    }
}
