import Foundation

enum HermesConfig {
    static var hermesDir: String { NSHomeDirectory() + "/.hermes" }
    static var defaultEnvPath: String { hermesDir + "/.env" }
    static var defaultConfigPath: String { hermesDir + "/config.yaml" }

    // MARK: - .env

    static func writeEnvKey(_ key: String, value: String, envPath: String = defaultEnvPath) throws {
        var lines = envLines(path: envPath)
        let prefix = key + "="
        var found = false
        for i in lines.indices {
            let trimmed = lines[i].trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix(prefix) || trimmed.hasPrefix("# " + prefix) || trimmed.hasPrefix("#" + prefix) {
                lines[i] = "\(key)=\(value)"
                found = true
                break
            }
        }
        if !found { lines.append("\(key)=\(value)") }
        try lines.joined(separator: "\n").write(toFile: envPath, atomically: true, encoding: .utf8)
    }

    static func removeEnvKey(_ key: String, envPath: String = defaultEnvPath) throws {
        var lines = envLines(path: envPath)
        let prefix = key + "="
        for i in lines.indices {
            let trimmed = lines[i].trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix(prefix) {
                lines[i] = "# " + lines[i]
            }
        }
        try lines.joined(separator: "\n").write(toFile: envPath, atomically: true, encoding: .utf8)
    }

    // Returns [envVarName: rawValue] for all non-commented, non-empty assignments.
    static func readConfiguredKeys(envPath: String = defaultEnvPath) -> [String: String] {
        var result: [String: String] = [:]
        for line in envLines(path: envPath) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.hasPrefix("#"), !trimmed.isEmpty else { continue }
            let parts = trimmed.split(separator: "=", maxSplits: 1)
            guard parts.count == 2 else { continue }
            let k = String(parts[0])
            let v = String(parts[1])
            guard !v.isEmpty else { continue }
            result[k] = v
        }
        return result
    }

    static func envLines(path: String = defaultEnvPath) -> [String] {
        (try? String(contentsOfFile: path, encoding: .utf8))?.components(separatedBy: "\n") ?? []
    }

    // MARK: - config.yaml

    static func writeConfigModel(modelId: String, provider: String, configPath: String = defaultConfigPath) throws {
        var content: String
        if let existing = try? String(contentsOfFile: configPath, encoding: .utf8) {
            content = existing
        } else {
            content = "model:\n  default: \(modelId)\n  provider: \(provider)\n"
            try content.write(toFile: configPath, atomically: true, encoding: .utf8)
            return
        }
        content = replaceLine(in: content, key: "  default:", newValue: "  default: \(modelId)")
        content = replaceLine(in: content, key: "  provider:", newValue: "  provider: \(provider)")
        try content.write(toFile: configPath, atomically: true, encoding: .utf8)
    }

    private static func replaceLine(in text: String, key: String, newValue: String) -> String {
        var lines = text.components(separatedBy: "\n")
        for i in lines.indices {
            if lines[i].hasPrefix(key) {
                lines[i] = newValue
                return lines.joined(separator: "\n")
            }
        }
        for i in lines.indices {
            if lines[i].trimmingCharacters(in: .whitespaces) == "model:" {
                lines.insert(newValue, at: i + 1)
                return lines.joined(separator: "\n")
            }
        }
        return text + "\n" + newValue
    }

    // MARK: - Key validation

    static func validateKey(preset: ModelPreset, apiKey: String) async -> Bool {
        guard let urlStr = preset.validationURL, let base = URL(string: urlStr) else { return true }

        var req: URLRequest
        if preset.useQueryAuth {
            var comps = URLComponents(url: base, resolvingAgainstBaseURL: false)!
            var items = comps.queryItems ?? []
            items.append(URLQueryItem(name: "key", value: apiKey))
            comps.queryItems = items
            req = URLRequest(url: comps.url ?? base)
        } else {
            req = URLRequest(url: base)
            req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }
        req.httpMethod = "GET"
        req.timeoutInterval = 10

        guard let (_, resp) = try? await URLSession.shared.data(for: req),
              let http = resp as? HTTPURLResponse else { return false }
        return http.statusCode != 401 && http.statusCode != 403
    }

    // MARK: - Helpers

    static func maskedKey(_ value: String) -> String {
        guard value.count > 8 else { return String(repeating: "•", count: value.count) }
        let visible = value.suffix(4)
        return "••••\(visible)"
    }
}
