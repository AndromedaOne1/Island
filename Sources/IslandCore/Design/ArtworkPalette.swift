import CoreGraphics
import SwiftUI

public struct ArtworkPalette: Equatable, Sendable {
    public let red: Double
    public let green: Double
    public let blue: Double
    public var color: Color { Color(red: red, green: green, blue: blue) }
    public static let fallback = Self(red: 0.82, green: 0.85, blue: 0.92)

    /// A small weighted sample ignores nearly black/white pixels, retaining the cover's hue.
    public static func sample(_ image: CGImage) -> Self {
        let dimension = IslandDesign.Artwork.palettePixels
        var pixels = [UInt8](repeating: 0, count: dimension * dimension * 4)
        let drawn = pixels.withUnsafeMutableBytes { bytes -> Bool in
            guard let context = CGContext(data: bytes.baseAddress, width: dimension, height: dimension,
                                          bitsPerComponent: 8, bytesPerRow: dimension * 4,
                                          space: CGColorSpaceCreateDeviceRGB(),
                                          bitmapInfo: CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
            context.draw(image, in: CGRect(x: 0, y: 0, width: dimension, height: dimension))
            return true
        }
        guard drawn else { return .fallback }
        var red = 0.0, green = 0.0, blue = 0.0, total = 0.0
        for index in stride(from: 0, to: pixels.count, by: 4) {
            let r = Double(pixels[index]) / 255, g = Double(pixels[index + 1]) / 255, b = Double(pixels[index + 2]) / 255
            let brightness = max(r, g, b)
            let saturation = brightness - min(r, g, b)
            guard brightness > IslandDesign.Artwork.minimumPaletteBrightness,
                  brightness < IslandDesign.Artwork.maximumPaletteBrightness,
                  saturation > IslandDesign.Artwork.minimumPaletteSaturation else { continue }
            let weight = saturation * Double(pixels[index + 3]) / 255
            red += r * weight; green += g * weight; blue += b * weight; total += weight
        }
        guard total > 0 else { return .fallback }
        red /= total; green /= total; blue /= total
        let average = (red + green + blue) / 3
        let boost = IslandDesign.Artwork.paletteSaturationBoost
        red = min(1, max(0, average + (red - average) * boost))
        green = min(1, max(0, average + (green - average) * boost))
        blue = min(1, max(0, average + (blue - average) * boost))
        let gain = max(1, IslandDesign.Artwork.accentBrightnessFloor / max(red, green, blue))
        return Self(red: min(1, red * gain), green: min(1, green * gain), blue: min(1, blue * gain))
    }
}

public struct IslandArtwork: View {
    let image: CGImage?
    let size: CGFloat
    @Environment(\.islandFeedback) private var feedback
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    public init(image: CGImage?, size: CGFloat) { self.image = image; self.size = size }
    public var body: some View {
        ZStack {
            if let image {
                Image(decorative: image, scale: 1).resizable().scaledToFill()
                    .transition(.islandContent(reduceMotion: reduceMotion))
            } else {
                IslandDesign.Colors.surface
                Image(systemName: "music.note").font(.system(size: size * IslandDesign.Artwork.placeholderSymbolRatio, weight: .medium))
                    .foregroundStyle(IslandDesign.Colors.secondary)
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * IslandDesign.Artwork.cornerRatio, style: .continuous))
        .shadow(color: .black.opacity(IslandDesign.Artwork.shadowOpacity),
                radius: size == IslandDesign.Artwork.compactSize ? 0 : IslandDesign.Artwork.shadowRadius,
                y: size == IslandDesign.Artwork.compactSize ? 0 : IslandDesign.Artwork.shadowOffset)
        .brightness(feedback.isHovered ? IslandDesign.Artwork.hoverBrightness : 0)
        .scaleEffect(feedback.isPressed && !reduceMotion ? IslandDesign.Motion.surfacePressedScale : 1)
        .animation(IslandDesign.Motion.hover, value: feedback)
        .animation(IslandDesign.Motion.content, value: image.map(ObjectIdentifier.init))
        .accessibilityLabel(image == nil ? "No artwork" : "Album artwork")
    }
}
