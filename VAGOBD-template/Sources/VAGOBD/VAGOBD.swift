import Foundation

/// VAG OBD2 Diagnostic Library
/// Supports Volkswagen, Audi, SEAT, and Skoda vehicles
public struct VAGOBD {

    /// Library version
    public static let version = "1.0.0"

    /// Supported vehicle brands
    public enum Brand: String, CaseIterable {
        case volkswagen = "Volkswagen"
        case audi = "Audi"
        case seat = "SEAT"
        case skoda = "Skoda"
    }

    public init() {}
}
