//
//  AppConfigService.swift
//  x2b
//

import Foundation

/// Fetches diagnostic and session info (`settings/appconfig.json`) from an X2B box -
/// network diagnostics mirroring `SettingsActivity.fetchInternalIpAndSystemId` on
/// Android, plus the box's currently logged-in user (`user.name`).
enum AppConfigService {
    struct BoxInfo {
        var internalIp: String = "--"
        var systemId: String = "--"
        var userName: String = ""
    }

    static func fetchBoxInfo(baseUrl: String) async -> BoxInfo {
        let normalized = URLNormalizer.normalizeBase(baseUrl)

        var jsonString = await fetchJSON(urlString: normalized + "/settings/appconfig.json")
        if jsonString == nil {
            let stripped = normalized
                .replacingOccurrences(of: "https://", with: "")
                .replacingOccurrences(of: "http://", with: "")
            jsonString = await fetchJSON(urlString: "http://\(stripped)/settings/appconfig.json")
        }

        guard let jsonString,
              let data = jsonString.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return BoxInfo()
        }

        var info = BoxInfo()

        if let lanURL = object["lanURL"] as? String, !lanURL.isEmpty {
            info.internalIp = lanURL
        } else if let interfaces = object["networkInterfaces"] as? [[String: Any]] {
            outer: for iface in interfaces {
                if let addresses = iface["addresses"] as? [String] {
                    for address in addresses where address.contains(".") && !address.contains(":") {
                        info.internalIp = address
                        break outer
                    }
                }
            }
        }

        if let system = object["system"] as? [String: Any], let id = system["id"] as? String {
            info.systemId = id
        }

        if let user = object["user"] as? [String: Any], let name = user["name"] as? String {
            info.userName = name
        }

        return info
    }

    private static func fetchJSON(urlString: String) async -> String? {
        guard let url = URL(string: urlString) else { return nil }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 4

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return nil }
            return String(data: data, encoding: .utf8)
        } catch {
            return nil
        }
    }
}
