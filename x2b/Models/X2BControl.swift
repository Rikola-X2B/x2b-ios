//
//  X2BControl.swift
//  x2b
//

import Foundation

/// A single control as reported by the box over the X2BWSS WebSocket protocol -
/// e.g. `{ "id": 1234567890001273, "type": "switch", "name": "Garagentor", "value": true }`.
struct X2BControl: Codable, Identifiable, Equatable {
    let id: Int
    let type: String
    let name: String
    let value: X2BControlValue
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
}
