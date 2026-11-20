#if canImport(UIKit)
import SwiftUI
import UIKit

/// Body, shading and fur drawn once into a bitmap covering box units -5..105.
enum BodyArt {
    static let px = 640, span = 110.0, pad = 5.0

    struct Key: Equatable {
        var rgba: [CGFloat]; var brightness: Double; var furLength: Double; var furDensity: Double; var seed: Int32
        var shape: BotShape
    }

    static func key(_ s: BotStyle, seed: Int32) -> Key {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(s.color).getRed(&r, green: &g, blue: &b, alpha: &a)
        return Key(rgba: [r, g, b, a], brightness: s.brightness, furLength: s.furLength, furDensity: s.furDensity, seed: seed, shape: s.shape)
    }

    static func shade(_ c: UIColor, _ k: CGFloat) -> UIColor {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        c.getRed(&r, green: &g, blue: &b, alpha: &a)
        return UIColor(red: min(r * k, 1), green: min(g * k, 1), blue: min(b * k, 1), alpha: a)
    }

    static func bake(_ style: BotStyle, seed: Int32) -> UIImage {
        let base = shade(UIColor(style.color), CGFloat(style.brightness))
        let fur = Fur.build(outline: style.shape.outline, seed: seed, length: style.furLength, density: style.furDensity)
        let fmt = UIGraphicsImageRendererFormat()
        fmt.scale = 1
        let size = CGSize(width: px, height: px)
        return UIGraphicsImageRenderer(size: size, format: fmt).image { rc in
            let g = rc.cgContext
            let k = CGFloat(px) / CGFloat(span)
            g.scaleBy(x: k, y: k)
            g.translateBy(x: CGFloat(pad), y: CGFloat(pad))
            let body = style.shape.outline.cgPath()
            lines(g, fur.rim, shade(base, 0.82), 0.75)
            g.setFillColor(base.cgColor); g.addPath(body); g.fillPath()
            g.saveGState(); g.addPath(body); g.clip()
            radial(g, UIColor.white.withAlphaComponent(0.34), .clear, CGPoint(x: 38, y: 38), 58, innerStop: 0)
            radial(g, .clear, UIColor.black.withAlphaComponent(0.30), CGPoint(x: 50, y: 62), 56, innerStop: 0.55)
            vertical(g)
            g.restoreGState()
            lines(g, fur.light, UIColor.white.withAlphaComponent(0.10), 0.5)
            lines(g, fur.dark, UIColor.black.withAlphaComponent(0.07), 0.5)
            lines(g, fur.rim, base.withAlphaComponent(0.35), 0.5)
        }
    }


    private static func lines(_ g: CGContext, _ l: [(CGPoint, CGPoint)], _ c: UIColor, _ w: CGFloat) {
        guard !l.isEmpty else { return }
        let p = CGMutablePath()
        for (a, b) in l { p.move(to: a); p.addLine(to: b) }
        g.setStrokeColor(c.cgColor); g.setLineWidth(w); g.setLineCap(.round)
        g.addPath(p); g.strokePath()
    }

    private static func radial(_ g: CGContext, _ from: UIColor, _ to: UIColor, _ c: CGPoint, _ r: CGFloat, innerStop: CGFloat) {
        guard let grad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                    colors: [from.cgColor, to.cgColor] as CFArray, locations: [innerStop, 1]) else { return }
        g.drawRadialGradient(grad, startCenter: c, startRadius: 0, endCenter: c, endRadius: r,
                             options: [.drawsBeforeStartLocation])
    }

    private static func vertical(_ g: CGContext) {
        let top = UIColor.clear.cgColor, bottom = UIColor.black.withAlphaComponent(0.16).cgColor
        guard let grad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                    colors: [top, top, bottom] as CFArray, locations: [0, 0.7, 1]) else { return }
        g.drawLinearGradient(grad, start: CGPoint(x: 0, y: 15), end: CGPoint(x: 0, y: 98), options: [.drawsAfterEndLocation])
    }
}
#endif
