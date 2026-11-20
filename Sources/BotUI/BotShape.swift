import CoreGraphics
import Foundation

/// One cubic Bezier piece of an outline.
struct Cubic: Equatable, Sendable {
    var p0: CGPoint, p1: CGPoint, p2: CGPoint, p3: CGPoint

    func point(_ t: CGFloat) -> CGPoint {
        let u = 1 - t
        return CGPoint(
            x: u*u*u*p0.x + 3*u*u*t*p1.x + 3*u*t*t*p2.x + t*t*t*p3.x,
            y: u*u*u*p0.y + 3*u*u*t*p1.y + 3*u*t*t*p2.y + t*t*t*p3.y)
    }

    var length: CGFloat {
        var total: CGFloat = 0, last = p0
        for i in 1...12 {
            let q = point(CGFloat(i) / 12)
            total += hypot(q.x - last.x, q.y - last.y); last = q
        }
        return total
    }

    func mapped(_ f: (CGPoint) -> CGPoint) -> Cubic { Cubic(p0: f(p0), p1: f(p1), p2: f(p2), p3: f(p3)) }

    static func line(_ a: CGPoint, _ b: CGPoint) -> Cubic {
        let d = CGPoint(x: (b.x - a.x) / 3, y: (b.y - a.y) / 3)
        return Cubic(p0: a, p1: CGPoint(x: a.x + d.x, y: a.y + d.y), p2: CGPoint(x: b.x - d.x, y: b.y - d.y), p3: b)
    }
}

/// A closed outline in the 100 x 100 body box.
struct BotOutline: Equatable, Sendable {
    let segments: [Cubic]
    let bounds: CGRect

    init(_ segments: [Cubic]) {
        self.segments = segments
        var minX = CGFloat.infinity, minY = CGFloat.infinity, maxX = -CGFloat.infinity, maxY = -CGFloat.infinity
        for s in segments {
            for i in 0...24 {
                let p = s.point(CGFloat(i) / 24)
                minX = min(minX, p.x); maxX = max(maxX, p.x); minY = min(minY, p.y); maxY = max(maxY, p.y)
            }
        }
        bounds = CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    func cgPath() -> CGPath {
        let p = CGMutablePath()
        guard let first = segments.first else { return p }
        p.move(to: first.p0)
        for s in segments { p.addCurve(to: s.p3, control1: s.p1, control2: s.p2) }
        p.closeSubpath()
        return p
    }

    /// About `n` points around the outline, spaced by arc length.
    func contour(_ n: Int) -> [CGPoint] {
        let lengths = segments.map(\.length)
        let total = max(lengths.reduce(0, +), 1e-3)
        var out: [CGPoint] = []
        for (s, len) in zip(segments, lengths) {
            let count = max(2, Int((CGFloat(n) * len / total).rounded()))
            for i in 0..<count { out.append(s.point(CGFloat(i) / CGFloat(count))) }
        }
        return out
    }

    /// Scaled to fit x 8...92 and stood on the ground (y = 98).
    func fitted() -> BotOutline? {
        guard bounds.width >= 1, bounds.height >= 1 else { return nil }
        let span: CGFloat = 84
        let k = min(span / bounds.width, span / bounds.height)
        let tx = 8 + span / 2 - k * bounds.midX
        let ty = 98 - k * bounds.maxY
        return BotOutline(segments.map { $0.mapped { CGPoint(x: $0.x * k + tx, y: $0.y * k + ty) } })
    }
}

/// Body outline. Presets are drawn for the face to sit right. `svg` takes any
/// SVG path string (`M L H V C S Q Z`, absolute or relative, any units): it is
/// scaled to fit and put on the ground. A bad path falls back to the teardrop.
public struct BotShape: Equatable, Sendable {
    let outline: BotOutline

    private init(_ outline: BotOutline) { self.outline = outline }

    public static let teardrop = BotShape(BotOutline([
        Cubic(p0: CGPoint(x: 50, y: 15), p1: CGPoint(x: 67.6, y: 15), p2: CGPoint(x: 80.8, y: 35), p3: CGPoint(x: 89.6, y: 55)),
        Cubic(p0: CGPoint(x: 89.6, y: 55), p1: CGPoint(x: 97.3, y: 71), p2: CGPoint(x: 94, y: 98), p3: CGPoint(x: 50, y: 98)),
        Cubic(p0: CGPoint(x: 50, y: 98), p1: CGPoint(x: 6, y: 98), p2: CGPoint(x: 2.7, y: 71), p3: CGPoint(x: 10.4, y: 55)),
        Cubic(p0: CGPoint(x: 10.4, y: 55), p1: CGPoint(x: 19.2, y: 35), p2: CGPoint(x: 32.4, y: 15), p3: CGPoint(x: 50, y: 15)),
    ]))
    public static let round = preset("M50 14C73.2 14 92 32.8 92 56C92 79.2 73.2 98 50 98C26.8 98 8 79.2 8 56C8 32.8 26.8 14 50 14Z")
    public static let egg = preset("M50 12C68 12 78 36 86 58C92 75 80 98 50 98C20 98 8 75 14 58C22 36 32 12 50 12Z")
    public static let blob = preset("M26 20C40 14 60 14 74 20C90 27 94 50 92 70C90 90 76 98 50 98C24 98 10 90 8 70C6 50 10 27 26 20Z")

    /// Soft six-petal flower, like the OpenAI mark.
    public static let blossom = svg("M50.0 0.0C52.1 0.0 54.4 0.7 56.4 1.7C58.3 2.8 60.1 4.6 61.8 6.1C63.4 7.6 64.7 9.6 66.2 11.0C67.6 12.4 68.9 13.7 70.5 14.6C72.0 15.5 73.8 15.9 75.7 16.5C77.7 17.0 80.0 17.2 82.1 17.9C84.3 18.5 86.8 19.2 88.6 20.4C90.5 21.6 92.2 23.2 93.3 25.0C94.4 26.8 94.9 29.2 95.0 31.4C95.1 33.6 94.4 36.1 93.9 38.2C93.4 40.4 92.4 42.5 91.9 44.5C91.4 46.4 90.9 48.2 90.9 50.0C90.9 51.8 91.4 53.6 91.9 55.5C92.4 57.5 93.4 59.6 93.9 61.8C94.4 63.9 95.1 66.4 95.0 68.6C94.9 70.8 94.4 73.2 93.3 75.0C92.2 76.8 90.5 78.4 88.6 79.6C86.8 80.8 84.3 81.5 82.1 82.1C80.0 82.8 77.7 83.0 75.7 83.5C73.8 84.1 72.0 84.5 70.5 85.4C68.9 86.3 67.6 87.6 66.2 89.0C64.7 90.4 63.4 92.4 61.8 93.9C60.1 95.4 58.3 97.2 56.4 98.3C54.4 99.3 52.1 100.0 50.0 100.0C47.9 100.0 45.6 99.3 43.6 98.3C41.7 97.2 39.9 95.4 38.2 93.9C36.6 92.4 35.3 90.4 33.8 89.0C32.4 87.6 31.1 86.3 29.5 85.4C28.0 84.5 26.2 84.1 24.3 83.5C22.3 83.0 20.0 82.8 17.9 82.1C15.7 81.5 13.2 80.8 11.4 79.6C9.5 78.4 7.8 76.8 6.7 75.0C5.6 73.2 5.1 70.8 5.0 68.6C4.9 66.4 5.6 63.9 6.1 61.8C6.6 59.6 7.6 57.5 8.1 55.5C8.6 53.6 9.1 51.8 9.1 50.0C9.1 48.2 8.6 46.4 8.1 44.5C7.6 42.5 6.6 40.4 6.1 38.2C5.6 36.1 4.9 33.6 5.0 31.4C5.1 29.2 5.6 26.8 6.7 25.0C7.8 23.2 9.5 21.6 11.4 20.4C13.2 19.2 15.7 18.5 17.9 17.9C20.0 17.2 22.3 17.0 24.3 16.5C26.2 15.9 28.0 15.5 29.5 14.6C31.1 13.7 32.4 12.4 33.8 11.0C35.3 9.6 36.6 7.6 38.2 6.1C39.9 4.6 41.7 2.8 43.6 1.7C45.6 0.7 47.9 -0.0 50.0 0.0Z")
    /// Rounded square, like a Grok tile.
    public static let squircle = svg("M50 0C90 0 100 10 100 50C100 90 90 100 50 100C10 100 0 90 0 50C0 10 10 0 50 0Z")

    /// Any SVG path, scaled to fit.
    public static func svg(_ path: String) -> BotShape {
        guard let segs = SVGPathParser.parse(path), let fitted = BotOutline(segs).fitted() else { return .teardrop }
        return BotShape(fitted)
    }

    private static func preset(_ path: String) -> BotShape {
        guard let segs = SVGPathParser.parse(path) else { return teardrop }
        return BotShape(BotOutline(segs))
    }
}

/// Reads the first sub-path of an SVG path string into cubic pieces. Arcs are not supported.
enum SVGPathParser {
    static func parse(_ text: String) -> [Cubic]? {
        var scan = Scanner(Array(text))
        var out: [Cubic] = []
        var cur = CGPoint.zero, start = CGPoint.zero, lastCtrl: CGPoint?, lastWasCubic = false
        var cmd: Character?
        var started = false

        func add(_ c: Cubic) { out.append(c); cur = c.p3 }

        while true {
            scan.skipSeparators()
            if scan.atEnd { break }
            if let ch = scan.peekLetter() {
                scan.advance(); cmd = ch
                if ch == "Z" || ch == "z" {
                    if cur != start { add(.line(cur, start)) }
                    break
                }
            } else if cmd == nil { return nil }
            guard let c = cmd else { return nil }
            let rel = c.isLowercase
            let o = rel ? cur : .zero
            switch Character(c.uppercased()) {
            case "M":
                if started { return finish(out) }
                guard let x = scan.number(), let y = scan.number() else { return nil }
                cur = CGPoint(x: x + o.x, y: y + o.y); start = cur; started = true
                cmd = rel ? "l" : "L"; lastWasCubic = false
            case "L":
                guard let x = scan.number(), let y = scan.number() else { return nil }
                add(.line(cur, CGPoint(x: x + o.x, y: y + o.y))); lastWasCubic = false
            case "H":
                guard let x = scan.number() else { return nil }
                add(.line(cur, CGPoint(x: x + o.x, y: cur.y))); lastWasCubic = false
            case "V":
                guard let y = scan.number() else { return nil }
                add(.line(cur, CGPoint(x: cur.x, y: y + o.y))); lastWasCubic = false
            case "C":
                guard let a = scan.numbers(6) else { return nil }
                let p1 = CGPoint(x: a[0] + o.x, y: a[1] + o.y), p2 = CGPoint(x: a[2] + o.x, y: a[3] + o.y)
                add(Cubic(p0: cur, p1: p1, p2: p2, p3: CGPoint(x: a[4] + o.x, y: a[5] + o.y)))
                lastCtrl = p2; lastWasCubic = true
            case "S":
                guard let a = scan.numbers(4) else { return nil }
                let p1 = lastWasCubic && lastCtrl != nil
                    ? CGPoint(x: 2 * cur.x - lastCtrl!.x, y: 2 * cur.y - lastCtrl!.y) : cur
                let p2 = CGPoint(x: a[0] + o.x, y: a[1] + o.y)
                add(Cubic(p0: cur, p1: p1, p2: p2, p3: CGPoint(x: a[2] + o.x, y: a[3] + o.y)))
                lastCtrl = p2; lastWasCubic = true
            case "Q":
                guard let a = scan.numbers(4) else { return nil }
                let q = CGPoint(x: a[0] + o.x, y: a[1] + o.y), e = CGPoint(x: a[2] + o.x, y: a[3] + o.y)
                let p1 = CGPoint(x: cur.x + 2 * (q.x - cur.x) / 3, y: cur.y + 2 * (q.y - cur.y) / 3)
                let p2 = CGPoint(x: e.x + 2 * (q.x - e.x) / 3, y: e.y + 2 * (q.y - e.y) / 3)
                add(Cubic(p0: cur, p1: p1, p2: p2, p3: e)); lastWasCubic = false
            default: return nil
            }
        }
        if cur != start { out.append(.line(cur, start)) }
        return finish(out)
    }

    private static func finish(_ segs: [Cubic]) -> [Cubic]? { segs.isEmpty ? nil : segs }

    private struct Scanner {
        let chars: [Character]
        var i = 0
        init(_ c: [Character]) { chars = c }
        var atEnd: Bool { i >= chars.count }
        mutating func advance() { i += 1 }

        mutating func skipSeparators() { while i < chars.count, chars[i].isWhitespace || chars[i] == "," { i += 1 } }

        func peekLetter() -> Character? {
            guard i < chars.count, chars[i].isLetter, chars[i] != "e", chars[i] != "E" else { return nil }
            return chars[i]
        }

        mutating func numbers(_ n: Int) -> [CGFloat]? {
            var out: [CGFloat] = []
            for _ in 0..<n { guard let v = number() else { return nil }; out.append(v) }
            return out
        }

        mutating func number() -> CGFloat? {
            skipSeparators()
            let begin = i
            if i < chars.count, chars[i] == "-" || chars[i] == "+" { i += 1 }
            var seenDot = false, digits = 0
            while i < chars.count {
                let c = chars[i]
                if c.isNumber { digits += 1; i += 1 }
                else if c == ".", !seenDot { seenDot = true; i += 1 }
                else { break }
            }
            if digits > 0, i < chars.count, chars[i] == "e" || chars[i] == "E" {
                var j = i + 1
                if j < chars.count, chars[j] == "-" || chars[j] == "+" { j += 1 }
                if j < chars.count, chars[j].isNumber {
                    while j < chars.count, chars[j].isNumber { j += 1 }
                    i = j
                }
            }
            guard digits > 0, let v = Double(String(chars[begin..<i])) else { i = begin; return nil }
            return CGFloat(v)
        }
    }
}
