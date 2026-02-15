import SwiftUI

extension Color {
    static let auraBackground = Color(hex: "000000")
    static let auraSurface = Color(hex: "1C1C1E")
    static let auraAccent = Color(hex: "FF2D55")
    static let auraAccentAlt = Color(hex: "A259FF")
    static let auraTextPrimary = Color.white
    static let auraTextSecondary = Color(hex: "8E8E93")

    init(hex: String) {
        let scanner = Scanner(string: hex)
        var rgbValue: UInt64 = 0
        scanner.scanHexInt64(&rgbValue)
        let r = Double((rgbValue & 0xFF0000) >> 16) / 255.0
        let g = Double((rgbValue & 0x00FF00) >> 8) / 255.0
        let b = Double(rgbValue & 0x0000FF) / 255.0
        self.init(red: r, green: g, blue: b)
    }
}
