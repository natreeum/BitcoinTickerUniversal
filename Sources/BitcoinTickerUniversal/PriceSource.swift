import Foundation

enum CurrencySymbol: String, Codable, CaseIterable, Identifiable, Sendable {
    case usd = "$"
    case krw = "₩"
    case jpy = "¥"
    case eur = "€"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .usd: return "USD ($)"
        case .krw: return "KRW (₩)"
        case .jpy: return "JPY (¥)"
        case .eur: return "EUR (€)"
        }
    }
}

struct PriceSource: Codable, Identifiable, Equatable, Sendable {
    var id: UUID
    var label: String
    var apiURL: String
    var responseKeyPath: String
    var refreshMilliseconds: Int
    var currencySymbol: CurrencySymbol

    init(
        id: UUID = UUID(),
        label: String,
        apiURL: String,
        responseKeyPath: String,
        refreshMilliseconds: Int,
        currencySymbol: CurrencySymbol = .usd
    ) {
        self.id = id
        self.label = label
        self.apiURL = apiURL
        self.responseKeyPath = responseKeyPath
        self.refreshMilliseconds = refreshMilliseconds
        self.currencySymbol = currencySymbol
    }

    private enum CodingKeys: String, CodingKey {
        case id, label, apiURL, responseKeyPath, refreshMilliseconds, currencySymbol
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        label = try container.decode(String.self, forKey: .label)
        apiURL = try container.decode(String.self, forKey: .apiURL)
        responseKeyPath = try container.decode(String.self, forKey: .responseKeyPath)
        refreshMilliseconds = try container.decode(Int.self, forKey: .refreshMilliseconds)
        currencySymbol = try container.decodeIfPresent(
            CurrencySymbol.self,
            forKey: .currencySymbol
        ) ?? .usd
    }

    static let defaultSource = PriceSource(
        label: "Coinbase BTC-USD",
        apiURL: "https://api.coinbase.com/v2/prices/BTC-USD/spot",
        responseKeyPath: "data.amount",
        refreshMilliseconds: 60_000
    )

    static let binanceSource = PriceSource(
        label: "Binance BTC-USDT",
        apiURL: "https://api.binance.com/api/v3/ticker/price?symbol=BTCUSDT",
        responseKeyPath: "price",
        refreshMilliseconds: 60_000
    )

    static let bybitSource = PriceSource(
        label: "Bybit BTC-USDT",
        apiURL: "https://api.bybit.com/v5/market/tickers?category=spot&symbol=BTCUSDT",
        responseKeyPath: "result.list.0.lastPrice",
        refreshMilliseconds: 60_000
    )

    static let builtInSources: [PriceSource] = [
        .defaultSource,
        .binanceSource,
        .bybitSource
    ]
}
