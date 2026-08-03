import SwiftUI

/// Provides the predefined color scheme used to render the small "square block" badge
/// shown next to a train's line number (e.g. `L1`, `R12`, `RE10`, `FLY1`, `L12x`) across
/// the app (routes board, train list, home favorites board, train route view, ...).
///
/// The color scheme is defined by the official line-number color legend:
/// - `L` (Lokaltog): green
/// - `F` (Fjerntog): dark blue
/// - `R` (Regiontog): red
/// - `RE` (Regionekspress): cyan
/// - `FLY` (Flytoget): orange
/// - `x`-suffixed variant lines are rendered as an outlined badge (white background,
///   colored border) instead of a solid fill, except for a few special-cased lines
///   that keep a solid fill (see `exactStyles`).
///
/// When no line number is available (the caller falls back to displaying the train
/// number instead), use `unavailable` — train numbers have no color scheme of their own.
enum LineNumberColorScheme {
    struct Style {
        let background: Color
        let border: Color?
        let foreground: Color
    }

    /// Style used when a train number is displayed instead of a line number.
    static let unavailable = Style(background: Color.secondary.opacity(0.55), border: nil, foreground: .white)

    /// Style used when a line number is present but not part of the known legend.
    private static let fallback = Style(background: Color.secondary.opacity(0.4), border: nil, foreground: .white)

    // MARK: - Base colors

    private static let lokaltogGreen = Color(red: 0.56, green: 0.78, blue: 0.25)
    private static let fjerntogBlue = Color(red: 0.10, green: 0.24, blue: 0.48)
    private static let regiontogRed = Color(red: 0.90, green: 0.06, blue: 0.12)
    private static let regionekspressCyan = Color(red: 0.0, green: 0.68, blue: 0.86)
    private static let flytogetOrange = Color(red: 0.93, green: 0.49, blue: 0.19)

    // MARK: - Variant (outline) colors

    private static let variantMagenta = Color(red: 0.85, green: 0.11, blue: 0.38)
    private static let variantGray = Color(red: 0.55, green: 0.55, blue: 0.58)
    private static let variantYellow = Color(red: 0.96, green: 0.65, blue: 0.14)
    private static let variantPurple = Color(red: 0.49, green: 0.34, blue: 0.76)
    private static let variantDarkGreen = Color(red: 0.17, green: 0.52, blue: 0.29)

    // MARK: - Exact per-line-number styles

    private static let exactStyles: [String: Style] = [
        // Lokaltog (L) — solid green, with a few outlined "x" variants.
        "L1": Style(background: lokaltogGreen, border: nil, foreground: .black),
        "L1X": Style(background: .white, border: variantMagenta, foreground: .black),
        "L2": Style(background: lokaltogGreen, border: nil, foreground: .black),
        "L2X": Style(background: .white, border: lokaltogGreen, foreground: .black),
        "L3": Style(background: lokaltogGreen, border: nil, foreground: .black),
        "L3X": Style(background: .white, border: lokaltogGreen, foreground: .black),
        "L4": Style(background: lokaltogGreen, border: nil, foreground: .black),
        "L5": Style(background: lokaltogGreen, border: nil, foreground: .black),

        // Fjerntog (F) — solid dark blue, with a couple of outlined "x" variants.
        "F1": Style(background: fjerntogBlue, border: nil, foreground: .white),
        "F1X": Style(background: .white, border: variantGray, foreground: .black),
        "F2": Style(background: fjerntogBlue, border: nil, foreground: .white),
        "F2X": Style(background: .white, border: variantGray, foreground: .black),
        "F3": Style(background: fjerntogBlue, border: nil, foreground: .white),
        "F4": Style(background: fjerntogBlue, border: nil, foreground: .white),
        "F5": Style(background: fjerntogBlue, border: nil, foreground: .white),
        "F6": Style(background: fjerntogBlue, border: nil, foreground: .white),
        "F7": Style(background: fjerntogBlue, border: nil, foreground: .white),
        "F8": Style(background: fjerntogBlue, border: nil, foreground: .white),

        // Regiontog (R) — solid red.
        "R12": Style(background: regiontogRed, border: nil, foreground: .white),
        "R13": Style(background: regiontogRed, border: nil, foreground: .white),
        "R14": Style(background: regiontogRed, border: nil, foreground: .white),
        "R21": Style(background: regiontogRed, border: nil, foreground: .white),
        "R22": Style(background: regiontogRed, border: nil, foreground: .white),
        "R23": Style(background: regiontogRed, border: nil, foreground: .white),
        "R31": Style(background: regiontogRed, border: nil, foreground: .white),
        "R40": Style(background: regiontogRed, border: nil, foreground: .white),
        "R45": Style(background: regiontogRed, border: nil, foreground: .white),
        "R50": Style(background: regiontogRed, border: nil, foreground: .white),
        "R60": Style(background: regiontogRed, border: nil, foreground: .white),
        "R65": Style(background: regiontogRed, border: nil, foreground: .white),
        "R70": Style(background: regiontogRed, border: nil, foreground: .white),
        "R71": Style(background: regiontogRed, border: nil, foreground: .white),
        "R75": Style(background: regiontogRed, border: nil, foreground: .white),
        "R80": Style(background: regiontogRed, border: nil, foreground: .white),

        // Regionekspress (RE) — solid cyan.
        "RE10": Style(background: regionekspressCyan, border: nil, foreground: .black),
        "RE11": Style(background: regionekspressCyan, border: nil, foreground: .black),
        "RE15": Style(background: regionekspressCyan, border: nil, foreground: .black),
        "RE20": Style(background: regionekspressCyan, border: nil, foreground: .black),
        "RE30": Style(background: regionekspressCyan, border: nil, foreground: .black),

        // Flytoget (FLY) — solid orange.
        "FLY1": Style(background: flytogetOrange, border: nil, foreground: .black),
        "FLY2": Style(background: flytogetOrange, border: nil, foreground: .black),

        // Special outlined variant lines and their exceptions.
        "L12X": Style(background: .white, border: regiontogRed, foreground: .black),
        "L13X": Style(background: .white, border: regiontogRed, foreground: .black),
        "R10X": Style(background: .white, border: regiontogRed, foreground: .black),
        "RX11": Style(background: .white, border: regionekspressCyan, foreground: .black),
        "L14X": Style(background: .white, border: variantYellow, foreground: .black),
        "L21X": Style(background: .white, border: variantPurple, foreground: .black),
        "L22X": Style(background: .white, border: variantPurple, foreground: .black),
        "R30X": Style(background: variantDarkGreen, border: nil, foreground: .white),
    ]

    /// Ordered so more specific prefixes (`RE`, `FLY`) are checked before their
    /// shorter overlapping counterparts (`R`, `F`).
    private static let prefixStyles: [(prefix: String, style: Style)] = [
        ("RE", Style(background: regionekspressCyan, border: nil, foreground: .black)),
        ("FLY", Style(background: flytogetOrange, border: nil, foreground: .black)),
        ("R", Style(background: regiontogRed, border: nil, foreground: .white)),
        ("F", Style(background: fjerntogBlue, border: nil, foreground: .white)),
        ("L", Style(background: lokaltogGreen, border: nil, foreground: .black)),
    ]

    /// Returns the badge style for a given line number, or `unavailable` when no
    /// line number exists (the caller is displaying a train number instead).
    static func style(forLineNumber lineNumber: String?) -> Style {
        guard let normalized = normalize(lineNumber) else {
            return unavailable
        }

        if let exact = exactStyles[normalized] {
            return exact
        }

        for entry in prefixStyles where normalized.hasPrefix(entry.prefix) {
            return entry.style
        }

        return fallback
    }

    private static func normalize(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
            return nil
        }

        return trimmed.uppercased()
    }
}

extension View {
    /// Applies the background fill, optional border and foreground text color for a
    /// line-number badge produced by `LineNumberColorScheme`.
    func lineNumberBadgeStyle(_ style: LineNumberColorScheme.Style, cornerRadius: CGFloat = 1) -> some View {
        self
            .foregroundStyle(style.foreground)
            .background(style.background, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay {
                if let border = style.border {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(border, lineWidth: 2)
                }
            }
    }
}
