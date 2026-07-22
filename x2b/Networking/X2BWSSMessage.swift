//
//  X2BWSSMessage.swift
//  x2b
//

import Foundation

/// Outgoing and incoming message shapes for the X2BWSS WebSocket protocol
/// (`wss://{box}.x2.energy/ws/x2b`). Every message is a JSON object with a `c`
/// (command) discriminator field.
enum X2BWSSOutgoing {
    struct GetControls: Encodable {
        let c = "GetControls"
    }

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

    struct GetControlsResponse: Decodable {
        let errorCode: Int?
        let errorMessage: String?
        let controls: [X2BControl]
    }

    struct RegisterControlsResponse: Decodable {
        let errorCode: Int?
        let errorMessage: String?
        let controls: [X2BControl]
    }

    struct ControlStatusUpdate: Decodable {
        let controls: [X2BControl]
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
        case "ControlStatusUpdate":
            guard let payload = try? decoder.decode(ControlStatusUpdate.self, from: data) else { return nil }
            return .controlStatusUpdate(payload)
        default:
            return nil
        }
    }

    enum Message {
        case getControlsResponse(GetControlsResponse)
        case registerControlsResponse(RegisterControlsResponse)
        case controlStatusUpdate(ControlStatusUpdate)
    }
}
