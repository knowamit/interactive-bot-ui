#if canImport(UIKit)
import SwiftUI
import UIKit

public enum BotFace: Sendable { case eyes, eyesAndMouth }

/// Everything you can customise. Colour and fur are independent of the mood
/// (`BotState`) so any colour works in any state.
public struct BotStyle {
    public var color: Color
    public var ink: Color
    public var face: BotFace
    /// Your own face. Replaces the state's preset face; the state still drives the motion.
    public var customFace: BotFaceSpec?
    /// 0.6 ... 1.6. Lightens or darkens the body colour.
    public var brightness: Double
    /// Fur strand length in body units (the body is 100 tall). 0 turns fur off.
    public var furLength: Double
    /// 0 ... 1
    public var furDensity: Double
    /// Optional ornament pinned to the crown. It turns and swings with the head.
    public var feather: UIImage?
    /// Overrides the hop interval for the current state; nil keeps the state's default.
    public var jumpEverySeconds: Double?
    /// Body outline: a preset like `.round`, or your own with `BotShape.svg(...)`.
    public var shape: BotShape

    public init(
        color: Color = Color(red: 0.56, green: 0.82, blue: 0.98), ink: Color = .white,
        face: BotFace = .eyesAndMouth, brightness: Double = 1.1, furLength: Double = 2.6,
        furDensity: Double = 0.75, feather: UIImage? = nil, jumpEverySeconds: Double? = nil,
        customFace: BotFaceSpec? = nil, shape: BotShape = .teardrop
    ) {
        self.color = color; self.ink = ink; self.face = face; self.brightness = brightness
        self.furLength = furLength; self.furDensity = furDensity; self.feather = feather
        self.jumpEverySeconds = jumpEverySeconds; self.customFace = customFace
        self.shape = shape;
    }
}
#endif
