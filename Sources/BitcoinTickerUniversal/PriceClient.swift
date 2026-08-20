import Foundation

enum PriceClientError: LocalizedError {
    case invalidURL
    case invalidResponse
    case missingValue(String)
    case unsupportedValue

    var errorDescription: String? {
        switch self {
        case .invalidURL: "The API URL is invalid."
        case .invalidResponse: "The server returned an invalid response."
        case .missingValue(let path): "No value exists at '\(path)'."
        case .unsupportedValue: "The selected response value is not numeric."
        }
    }
}

struct ResponseValueOption: Identifiable, Equatable {
    var id: String { keyPath }
    let keyPath: String
    let displayValue: String
    let isNumeric: Bool
}

struct PriceClient: Sendable {
    func fetchPrice(from source: PriceSource) async throws -> Decimal {
        guard let url = URL(string: source.apiURL),
              let scheme = url.scheme,
              ["http", "https"].contains(scheme.lowercased()) else {
            throw PriceClientError.invalidURL
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 15
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue("BitcoinTickerUniversal/1.0", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await requestData(request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            throw PriceClientError.invalidResponse
        }

        let json = try JSONSerialization.jsonObject(with: data)
        guard let value = value(in: json, at: source.responseKeyPath) else {
            throw PriceClientError.missingValue(source.responseKeyPath)
        }

        if let decimal = decimalValue(from: value) {
            return decimal
        }
        throw PriceClientError.unsupportedValue
    }

    func fetchResponseValueOptions(from apiURL: String) async throws -> [ResponseValueOption] {
        guard let url = URL(string: apiURL),
              let scheme = url.scheme,
              ["http", "https"].contains(scheme.lowercased()) else {
            throw PriceClientError.invalidURL
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 15
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue("BitcoinTickerUniversal/1.0", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await requestData(request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            throw PriceClientError.invalidResponse
        }

        let json = try JSONSerialization.jsonObject(with: data)
        return flattenedOptions(from: json)
    }

    private func requestData(_ request: URLRequest) async throws -> (Data, URLResponse) {
        try await withCheckedThrowingContinuation { continuation in
            URLSession.shared.dataTask(with: request) { data, response, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let data, let response else {
                    continuation.resume(throwing: PriceClientError.invalidResponse)
                    return
                }
                continuation.resume(returning: (data, response))
            }.resume()
        }
    }

    private func value(in json: Any, at keyPath: String) -> Any? {
        let components = keyPath.split(separator: ".").map(String.init)
        guard !components.isEmpty else { return json }

        return components.reduce(Optional(json)) { current, component in
            guard let current else { return nil }
            if let dictionary = current as? [String: Any] {
                return dictionary[component]
            }
            if let array = current as? [Any],
               let index = Int(component), array.indices.contains(index) {
                return array[index]
            }
            return nil
        }
    }

    private func flattenedOptions(from json: Any) -> [ResponseValueOption] {
        var options: [ResponseValueOption] = []

        func walk(_ value: Any, path: String) {
            if let dictionary = value as? [String: Any] {
                for key in dictionary.keys.sorted() {
                    let childPath = path.isEmpty ? key : "\(path).\(key)"
                    walk(dictionary[key] as Any, path: childPath)
                }
                return
            }

            if let array = value as? [Any] {
                for (index, child) in array.enumerated() {
                    let childPath = path.isEmpty ? "\(index)" : "\(path).\(index)"
                    walk(child, path: childPath)
                }
                return
            }

            let keyPath = path.isEmpty ? "$" : path
            options.append(
                ResponseValueOption(
                    keyPath: keyPath,
                    displayValue: displayString(from: value),
                    isNumeric: decimalValue(from: value) != nil
                )
            )
        }

        walk(json, path: "")
        return options
    }

    private func decimalValue(from value: Any) -> Decimal? {
        if let number = value as? NSNumber {
            return number.decimalValue
        }
        if let string = value as? String {
            return Decimal(string: string, locale: Locale(identifier: "en_US_POSIX"))
        }
        return nil
    }

    private func displayString(from value: Any) -> String {
        if value is NSNull {
            return "null"
        }
        if let string = value as? String {
            return "\"\(string)\""
        }
        if let number = value as? NSNumber {
            return number.stringValue
        }
        return String(describing: value)
    }
}
