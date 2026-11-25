import SwiftUI

// Linen brand color. Mint green is the app accent everywhere: buttons,
// links, toggles, selection states, and the sender bubbles in messaging
// all read from here. LinenApp sets mint as the root tint so every
// control inherits it. Directed 2026-11-24 to replace the pink the
// build was using.
enum LinenTheme {
    // Mint green, #3EB489.
    static let mint = Color(red: 62.0 / 255.0, green: 180.0 / 255.0, blue: 137.0 / 255.0)
    // Deep mint for text and icons on light surfaces, #2A7F62.
    static let mintDeep = Color(red: 42.0 / 255.0, green: 127.0 / 255.0, blue: 98.0 / 255.0)
    // Soft mint tint for chips and selected rows, #DFF5EA.
    static let mintSoft = Color(red: 223.0 / 255.0, green: 245.0 / 255.0, blue: 234.0 / 255.0)
}
