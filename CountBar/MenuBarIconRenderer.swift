import AppKit

enum MenuBarIconRenderer {
    static func render(progress: Double, pointSize: CGFloat, appearance: NSAppearance) -> NSImage {
        let config = NSImage.SymbolConfiguration(pointSize: pointSize, weight: .semibold)

        // Disc + hash, palette-colored, appearance-aware
        let isDark = appearance.bestMatch(from: [.darkAqua, .vibrantDark]) != nil
        let discColor: NSColor = isDark ? .black : .white
        let hashColor: NSColor = isDark ? .white : .black

        let fillConfig = config.applying(.init(paletteColors: [hashColor, discColor]))
        let fill = NSImage(systemSymbolName: "number.circle.fill",
                           accessibilityDescription: nil)?
            .withSymbolConfiguration(fillConfig) ?? NSImage()

        // Variable progress ring with threshold-based color
        let ringConfig = config.applying(.init(paletteColors: [ringColor(for: progress)]))
        let ring = NSImage(systemSymbolName: "number.circle",
                           variableValue: min(progress, 1.0),
                           accessibilityDescription: nil)?
            .withSymbolConfiguration(ringConfig) ?? NSImage()

        let size = fill.size
        let result = NSImage(size: size)

        result.lockFocusFlipped(false)
        let previousAppearance = NSAppearance.current
        NSAppearance.current = appearance
        NSGraphicsContext.current?.imageInterpolation = .high

        fill.draw(in: NSRect(origin: .zero, size: size))
        ring.draw(in: NSRect(origin: .zero, size: size))

        NSAppearance.current = previousAppearance
        result.unlockFocus()
        result.isTemplate = false
        return result
    }

    private static func ringColor(for progress: Double) -> NSColor {
        switch progress {
        case ..<0.25:  return .systemRed
        case ..<0.50:  return .systemOrange
        case ..<0.75:  return .systemYellow
        case ..<1.00:  return .systemBlue
        default:       return .systemGreen
        }
    }
}
