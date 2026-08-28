import SwiftUI

extension Color {
    static let brand = Color(red: 0.196, green: 0.808, blue: 0.416)
}

extension ShapeStyle where Self == Color {
    static var brand: Color { .brand }
}
