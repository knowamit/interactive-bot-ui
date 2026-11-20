import BotUI
import SwiftUI

@main
struct DemoApp: App {
    var body: some Scene { WindowGroup { DemoView() } }
}

private let swatches: [(String, Color)] = [
    ("Sky", Color(red: 0.56, green: 0.82, blue: 0.98)),
    ("Nojoto", Color(red: 0.96, green: 0.16, blue: 0.16)),
    ("Mint", Color(red: 0.12, green: 0.83, blue: 0.78)),
    ("Sun", Color(red: 1.0, green: 0.77, blue: 0.24)),
    ("Plum", Color(red: 0.56, green: 0.36, blue: 0.85)),
    ("Rose", Color(red: 1.0, green: 0.48, blue: 0.66)),
]

private let shapes: [(String, BotShape)] = [
    ("Teardrop", .teardrop), ("Round", .round), ("Egg", .egg), ("Blob", .blob),
    ("Blossom", .blossom),
    ("Squircle", .squircle),
    ("Bean", .svg("M20 40C20 10 80 10 80 40C95 55 85 95 50 95C15 95 5 55 20 40Z")),
]

struct DemoView: View {
    @State private var state: BotState = .neutral
    @State private var color = swatches[1].1
    @State private var brightness = 1.1
    @State private var furLength = 2.6
    @State private var mouth = true
    @State private var feather = true
    @State private var custom = false
    @State private var eyes = BotEyes.oval
    @State private var mouthShape = BotMouth.smile
    @State private var eyeScale = 1.0
    @State private var eyeTilt = 0.0
    @State private var shapeName = "Teardrop"

    private static func arg(_ name: String) -> String? {
        let args = ProcessInfo.processInfo.arguments
        guard let i = args.firstIndex(of: name), i + 1 < args.count else { return nil }
        return args[i + 1]
    }

    init() {
        let start = Self.arg("-state").flatMap { n in BotState.allCases.first { "\($0)" == n } }
        _state = State(initialValue: start ?? .neutral)
        let named = Self.arg("-shape").flatMap { n in shapes.first { $0.0.lowercased() == n.lowercased() }?.0 }
        _shapeName = State(initialValue: named ?? "Teardrop")
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Spacer()
                    BotView(
                        state: state,
                        style: BotStyle(
                            color: color, face: mouth ? .eyesAndMouth : .eyes, brightness: brightness,
                            furLength: furLength, feather: feather ? UIImage(named: "feather") : nil,
                            customFace: custom
                                ? BotFaceSpec(eyes: eyes, mouth: mouthShape, eyeScale: eyeScale,
                                                eyeTilt: eyeTilt)
                                : nil,
                            shape: shapes.first { $0.0 == shapeName }?.1 ?? .teardrop),
                        seed: 0.11 + Double(BotState.allCases.firstIndex(of: state) ?? 0) * 0.17)
                        .frame(width: 260, height: 260)
                    Spacer()
                }
                .padding(.top, 40)
                Text("Mood")
                chips(BotState.allCases, selection: $state)
                Toggle("Custom face", isOn: $custom)
                if custom {
                    Text("Eyes")
                    chips(BotEyes.allCases, selection: $eyes)
                    Text("Mouth")
                    chips(BotMouth.allCases, selection: $mouthShape)
                    Text(String(format: "Eye size %.2f", eyeScale))
                    Slider(value: $eyeScale, in: 0.5...1.6)
                    Text(String(format: "Eye tilt %.2f (angry to sad)", eyeTilt))
                    Slider(value: $eyeTilt, in: -1...1)
                }
                Text("Body shape")
                chips(shapes.map(\.0), selection: $shapeName)
                Text("Tap BotUI to giggle, hold for love").foregroundColor(.gray)
                Text("Colour")
                HStack(spacing: 10) {
                    ForEach(swatches, id: \.0) { name, c in
                        Circle().fill(c).frame(width: 38, height: 38)
                            .overlay(Circle().stroke(Color.black, lineWidth: c == color ? 3 : 0))
                            .onTapGesture { color = c }
                            .accessibilityLabel(name)
                    }
                }
                Text(String(format: "Brightness %.2f", brightness))
                Slider(value: $brightness, in: 0.6...1.6)
                Text(String(format: "Fur length %.1f", furLength))
                Slider(value: $furLength, in: 0...7)
                Toggle("Mouth", isOn: $mouth)
                Toggle("Feather", isOn: $feather)
            }
            .padding(20)
        }
        .background(Color.white)
    }
}

private struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        arrange(proposal.width ?? 360, subviews).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        for (view, origin) in zip(subviews, arrange(bounds.width, subviews).origins) {
            view.place(at: CGPoint(x: bounds.minX + origin.x, y: bounds.minY + origin.y), proposal: .unspecified)
        }
    }

    private func arrange(_ width: CGFloat, _ subviews: Subviews) -> (size: CGSize, origins: [CGPoint]) {
        var x = 0.0, y = 0.0, rowH = 0.0, origins: [CGPoint] = []
        for v in subviews {
            let s = v.sizeThatFits(.unspecified)
            if x + s.width > width, x > 0 { x = 0; y += rowH + spacing; rowH = 0 }
            origins.append(CGPoint(x: x, y: y))
            x += s.width + spacing; rowH = max(rowH, s.height)
        }
        return (CGSize(width: width, height: y + rowH), origins)
    }
}

@ViewBuilder
private func chips<T: Hashable>(_ all: [T], selection: Binding<T>) -> some View {
    FlowLayout {
        ForEach(all, id: \.self) { v in
            Text("\(String(describing: v))".prefix(1).uppercased() + "\(v)".dropFirst())
                .font(.footnote)
                .padding(.horizontal, 10).padding(.vertical, 6)
                .background(Capsule().fill(v == selection.wrappedValue ? Color.accentColor.opacity(0.2) : Color.gray.opacity(0.12)))
                .onTapGesture { selection.wrappedValue = v }
        }
    }
}
