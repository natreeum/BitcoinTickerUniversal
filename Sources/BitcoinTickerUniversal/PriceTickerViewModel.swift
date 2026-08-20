import Combine
import Foundation

@MainActor
final class PriceTickerViewModel: ObservableObject {
    @Published private(set) var displayPrice = "--"
    @Published private(set) var lastError: String?
    @Published private(set) var isRefreshing = false

    private let store: PriceSourceStore
    private let client: PriceClient
    private var refreshTask: Task<Void, Never>?
    private var pollingGeneration = UUID()
    private var cancellables = Set<AnyCancellable>()

    init(store: PriceSourceStore, client: PriceClient = PriceClient()) {
        self.store = store
        self.client = client

        store.$selectedSourceID
            .combineLatest(store.$sources)
            .map { selectedSourceID, sources in
                guard let selectedSourceID else { return sources.first }
                return sources.first(where: { $0.id == selectedSourceID }) ?? sources.first
            }
            .removeDuplicates()
            .sink { [weak self] source in self?.restartPolling(with: source) }
            .store(in: &cancellables)
    }

    deinit {
        refreshTask?.cancel()
    }

    func restartPolling() {
        restartPolling(with: store.selectedSource)
    }

    private func restartPolling(with source: PriceSource?) {
        refreshTask?.cancel()
        pollingGeneration = UUID()
        guard let source else {
            displayPrice = "--"
            return
        }
        displayPrice = "--"
        let generation = pollingGeneration

        refreshTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.refresh(source: source, generation: generation)
                let milliseconds = max(source.refreshMilliseconds, 250)
                let nanoseconds = UInt64(milliseconds) * 1_000_000
                try? await Task.sleep(nanoseconds: nanoseconds)
            }
        }
    }

    func refreshNow() {
        guard let source = store.selectedSource else { return }
        let generation = pollingGeneration
        Task { await refresh(source: source, generation: generation) }
    }

    private func refresh(source: PriceSource, generation: UUID) async {
        guard generation == pollingGeneration else { return }
        isRefreshing = true
        defer {
            if generation == pollingGeneration {
                isRefreshing = false
            }
        }

        do {
            let price = try await client.fetchPrice(from: source)
            guard generation == pollingGeneration, !Task.isCancelled else { return }
            displayPrice = Self.format(price, currencySymbol: source.currencySymbol)
            lastError = nil
        } catch is CancellationError {
            return
        } catch {
            guard generation == pollingGeneration, !Task.isCancelled else { return }
            displayPrice = "--"
            lastError = error.localizedDescription
        }
    }

    private static func format(
        _ price: Decimal,
        currencySymbol: CurrencySymbol
    ) -> String {
        let number = NSDecimalNumber(decimal: price)
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = false
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 0
        return "\(currencySymbol.rawValue)\(formatter.string(from: number) ?? number.stringValue)"
    }
}
