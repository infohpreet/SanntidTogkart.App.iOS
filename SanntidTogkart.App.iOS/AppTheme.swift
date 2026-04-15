import SwiftUI
import UIKit

enum AppTheme {
    static let background = Color(
        uiColor: UIColor { traits in
            if traits.userInterfaceStyle == .dark {
                return UIColor(red: 0.09, green: 0.10, blue: 0.19, alpha: 1.0)
            }

            return .systemBackground
        }
    )

    static let surface = Color(
        uiColor: UIColor { traits in
            if traits.userInterfaceStyle == .dark {
                return UIColor(red: 0.22, green: 0.23, blue: 0.31, alpha: 1.0)
            }

            return .secondarySystemBackground
        }
    )

    static let elevatedSurface = Color(
        uiColor: UIColor { traits in
            if traits.userInterfaceStyle == .dark {
                return UIColor(red: 0.27, green: 0.28, blue: 0.36, alpha: 1.0)
            }

            return .tertiarySystemBackground
        }
    )

    static let chrome = Color(
        uiColor: UIColor { traits in
            if traits.userInterfaceStyle == .dark {
                return UIColor(red: 0.14, green: 0.15, blue: 0.24, alpha: 1.0)
            }

            return .systemBackground
        }
    )

    static let border = Color(
        uiColor: UIColor { traits in
            if traits.userInterfaceStyle == .dark {
                return UIColor(red: 0.47, green: 0.49, blue: 0.66, alpha: 0.22)
            }

            return UIColor(white: 0.0, alpha: 0.06)
        }
    )

    static let readableContentWidth: CGFloat = 580
}

extension View {
    func appReadableContentWidth(_ maxWidth: CGFloat = AppTheme.readableContentWidth) -> some View {
        self
            .frame(maxWidth: maxWidth, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .center)
    }
}
