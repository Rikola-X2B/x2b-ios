//
//  X2BControl.swift
//  x2b
//

import Foundation

/// A single control as reported by the box over the X2BCP WebSocket API - e.g.
/// `{ "id": 1234567890001273, "type": "switch", "name": "Garagentor", "value": true,
/// "alterable": true }`.
///
/// The API defines exactly four `type` values: `"switch"` (bool on/off),
/// `"pushButton"` (bool, turns itself back off after a moment - used for scenes),
/// `"text"` (display-only string), and `"light"` (bool on/off, semantically a light).
/// `alterable` is false for display-only controls *and* for controls the user simply
/// isn't allowed/able to operate right now, independent of `type`.
struct X2BControl: Codable, Identifiable, Equatable {
    static let typeSwitch = "switch"
    static let typePushButton = "pushButton"
    static let typeText = "text"
    static let typeLight = "light"

    let id: Int
    let type: String
    let name: String
    let value: X2BControlValue
    let alterable: Bool
}

/// A control's `value` can be a bool, a number, a string, or unknown/undefined (null) -
/// the protocol doesn't fix this per control type, so this decodes/encodes whichever
/// one is actually present.
enum X2BControlValue: Codable, Equatable {
    case bool(Bool)
    case number(Double)
    case string(String)
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let boolValue = try? container.decode(Bool.self) {
            self = .bool(boolValue)
        } else if let numberValue = try? container.decode(Double.self) {
            self = .number(numberValue)
        } else if let stringValue = try? container.decode(String.self) {
            self = .string(stringValue)
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unsupported X2B control value type"
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .bool(let value): try container.encode(value)
        case .number(let value): try container.encode(value)
        case .string(let value): try container.encode(value)
        case .null: try container.encodeNil()
        }
    }

    var boolValue: Bool? {
        switch self {
        case .bool(let value): return value
        case .number(let value): return value != 0
        default: return nil
        }
    }

    /// A short, human-presentable form regardless of the underlying type - used by
    /// "Wertanzeige" (readOnly) slots, whose value could be a string, a number (e.g. a
    /// temperature), or a bool, depending on what's actually assigned.
    var displayString: String {
        switch self {
        case .bool(let value): return value ? "Ein" : "Aus"
        case .number(let value):
            return value.truncatingRemainder(dividingBy: 1) == 0
                ? String(Int(value))
                : String(format: "%.1f", value)
        case .string(let value): return value
        case .null: return "–"
        }
    }
}
