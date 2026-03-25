import SwiftUI
import UIKit

enum AppTheme {
    static let background = Color(
        uiColor: UIColor { traits in
            if traits.userInterfaceStyle == .dark {
                return UIColor(red: 0.18, green: 0.19, blue: 0.21, alpha: 1.0)
            }

            return .systemBackground
        }
    )

    static let surface = Color(
        uiColor: UIColor { traits in
            if traits.userInterfaceStyle == .dark {
                return UIColor(red: 0.22, green: 0.23, blue: 0.26, alpha: 1.0)
            }

            return .secondarySystemBackground
        }
    )

    static let elevatedSurface = Color(
        uiColor: UIColor { traits in
            if traits.userInterfaceStyle == .dark {
                return UIColor(red: 0.26, green: 0.27, blue: 0.31, alpha: 1.0)
            }

            return .tertiarySystemBackground
        }
    )

    static let chrome = Color(
        uiColor: UIColor { traits in
            if traits.userInterfaceStyle == .dark {
                return UIColor(red: 0.16, green: 0.17, blue: 0.19, alpha: 1.0)
            }

            return .systemBackground
        }
    )

    static let border = Color(
        uiColor: UIColor { traits in
            if traits.userInterfaceStyle == .dark {
                return UIColor(white: 1.0, alpha: 0.08)
            }

            return UIColor(white: 0.0, alpha: 0.06)
        }
    )
}
