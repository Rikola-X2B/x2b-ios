//
//  X2BWSSMessage.swift
//  x2b
//

import Foundation

/// Outgoing and incoming message shapes for the X2BCP WebSocket API
/// (`wss://{box}.x2.energy/ws/x2b`, subprotocol `X2BCP`). Every message is a JSON
/// object with a `c` (command) discriminator field.
enum X2BWSSOutgoing {
    struct GetControls: Encodable {
        let c = "GetControls"
    }

    /// Implicitly un-registers every previously registered control - there's no
    /// separate "unlisten" message. Sending an empty `ids` array un-registers all of
    /// them.
    struct RegisterControls: Encodable {
        let c = "RegisterControls"
        let ids: [Int]
    }

    struct SetControlValue: Encodable {
        let c = "SetControlValue"
        let id: Int
        let value: X2BControlValue
    }
}

enum X2BWSSIncoming {
    /// Just enough to read `c` and dispatch to the right concrete type below.
    struct Envelope: Decodable {
        let c: String
    }

    /// Per the API's error handling rules: when `errorCode` is present, the normal
    /// data fields may be absent or invalid and must be ignored - so `controls`/
    /// `control` are optional here rather than required, and callers should treat a
    /// missing value as "nothing usable came back", not fail to decode entirely.
    struct GetControlsResponse: Decodable {
        let errorCode: Int?
        let errorMessage: String?
        let controls: [X2BControl]?
    }

    struct RegisterControlsResponse: Decodable {
        let errorCode: Int?
        let errorMessage: String?
        let controls: [X2BControl]?
    }

    struct ControlValueUpdate: Decodable {
        let controls: [X2BControl]
    }

    struct SetControlValueResponse: Decodable {
        let errorCode: Int?
        let errorMessage: String?
        let control: X2BControl?
    }

    static func decode(_ data: Data) -> Message? {
        guard let envelope = try? JSONDecoder().decode(Envelope.self, from: data) else { return nil }
        let decoder = JSONDecoder()
        switch envelope.c {
        case "GetControlsResponse":
            guard let payload = try? decoder.decode(GetControlsResponse.self, from: data) else { return nil }
            return .getControlsResponse(payload)
        case "RegisterControlsResponse":
            guard let payload = try? decoder.decode(RegisterControlsResponse.self, from: data) else { return nil }
            return .registerControlsResponse(payload)
        case "ControlValueUpdate":
            guard let payload = try? decoder.decode(ControlValueUpdate.self, from: data) else { return nil }
            return .controlValueUpdate(payload)
        case "SetControlValueResponse":
            guard let payload = try? decoder.decode(SetControlValueResponse.self, from: data) else { return nil }
            return .setControlValueResponse(payload)
        default:
            return nil
        }
    }

    enum Message {
        case getControlsResponse(GetControlsResponse)
        case registerControlsResponse(RegisterControlsResponse)
        case controlValueUpdate(ControlValueUpdate)
        case setControlValueResponse(SetControlValueResponse)
    }
}
