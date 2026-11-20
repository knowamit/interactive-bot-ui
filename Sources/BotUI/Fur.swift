import CoreGraphics
import Foundation

/// Fur strokes in body units, as start/end pairs.
struct FurStrokes {
    var rim: [(CGPoint, CGPoint)] = []
    var light: [(CGPoint, CGPoint)] = []
    var dark: [(CGPoint, CGPoint)] = []
}

enum Fur {
    private static let cx = 50.0, cy = 60.0

    static func build(outline: BotOutline, seed: Int32, length: Double, density: Double) -> FurStrokes {
        guard length > 0, density > 0 else { return FurStrokes() }
        var rng = SeededRandom(seed: seed)
        let c = outline.contour(240)
        let box = outline.bounds
        return FurStrokes(
            rim: rim(c, &rng, Int(1500 * density), length),
            light: interior(c, box, &rng, Int(1700 * density), length * 0.7),
            dark: interior(c, box, &rng, Int(1300 * density), length * 0.7))
    }

    private static func rim(_ c: [CGPoint], _ rng: inout SeededRandom, _ count: Int, _ length: Double) -> [(CGPoint, CGPoint)] {
        var out: [(CGPoint, CGPoint)] = []
        out.reserveCapacity(count)
        for _ in 0..<count {
            let i = min(Int(rng.next() * Double(c.count)), c.count - 1)
            let p = c[i], q = c[(i + 1) % c.count]
            let tx = Double(q.x - p.x), ty = Double(q.y - p.y)
            let tl = max(hypot(tx, ty), 1e-3)
            var nx = ty / tl, ny = -tx / tl
            if nx * (Double(p.x) - cx) + ny * (Double(p.y) - cy) < 0 { nx = -nx; ny = -ny }
            let a = atan2(ny, nx) + rng.range(-0.5, 0.5)
            let len = length * rng.range(0.4, 1.0)
            let dx = cos(a) * len, dy = sin(a) * len + len * 0.25
            out.append((CGPoint(x: Double(p.x) - dx * 0.4, y: Double(p.y) - dy * 0.4),
                        CGPoint(x: Double(p.x) + dx, y: Double(p.y) + dy)))
        }
        return out
    }

    private static func interior(_ c: [CGPoint], _ box: CGRect, _ rng: inout SeededRandom, _ count: Int, _ length: Double) -> [(CGPoint, CGPoint)] {
        var out: [(CGPoint, CGPoint)] = []
        out.reserveCapacity(count)
        var guardCount = 0
        while out.count < count, guardCount < count * 8 {
            guardCount += 1
            let p = CGPoint(x: rng.range(Double(box.minX), Double(box.maxX)), y: rng.range(Double(box.minY), Double(box.maxY)))
            if !inside(c, p) { continue }
            let a = atan2(Double(p.y) - cy, Double(p.x) - cx) + rng.range(-0.7, 0.7)
            let len = length * rng.range(0.6, 1.2)
            let dx = cos(a) * len, dy = sin(a) * len + len * 0.45
            out.append((p, CGPoint(x: Double(p.x) + dx, y: Double(p.y) + dy)))
        }
        return out
    }

    private static func inside(_ poly: [CGPoint], _ p: CGPoint) -> Bool {
        var hit = false
        var j = poly.count - 1
        for i in poly.indices {
            let a = poly[i], b = poly[j]
            if (a.y > p.y) != (b.y > p.y), p.x < (b.x - a.x) * (p.y - a.y) / (b.y - a.y) + a.x { hit.toggle() }
            j = i
        }
        return hit
    }
}
