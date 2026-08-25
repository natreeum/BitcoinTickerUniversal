import Combine
import Foundation

@MainActor
final class PriceSourceStore: ObservableObject {
    @Published var sources: [PriceSource] {
        didSet { persist() }
    }

    @Published var selectedSourceID: UUID? {
        didSet { persist() }
    }

    private let defaults: UserDefaults
    private let sourcesKey = "priceSources"
    private let selectedSourceKey = "selectedPriceSourceID"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        var loadedSources: [PriceSource]
        if let data = defaults.data(forKey: sourcesKey),
           let decoded = try? JSONDecoder().decode([PriceSource].self, from: data),
           !decoded.isEmpty {
            loadedSources = decoded
        } else {
            loadedSources = PriceSource.builtInSources
        }

        if let coinbaseIndex = loadedSources.firstIndex(where: {
            $0.apiURL == PriceSource.defaultSource.apiURL && $0.refreshMilliseconds == 5_000
        }) {
            loadedSources[coinbaseIndex].refreshMilliseconds = 60_000
        }

        for builtInSource in PriceSource.builtInSources where !loadedSources.contains(where: {
            $0.apiURL == builtInSource.apiURL
        }) {
            loadedSources.append(builtInSource)
        }

        sources = loadedSources

        if let rawID = defaults.string(forKey: selectedSourceKey),
           let id = UUID(uuidString: rawID),
           sources.contains(where: { $0.id == id }) {
            selectedSourceID = id
        } else {
            selectedSourceID = sources.first?.id
        }

        persist()
    }

    var selectedSource: PriceSource? {
        guard let selectedSourceID else { return sources.first }
        return sources.first(where: { $0.id == selectedSourceID }) ?? sources.first
    }

    func select(_ source: PriceSource) {
        selectedSourceID = source.id
    }

    func updateSource(_ source: PriceSource) {
        guard let index = sources.firstIndex(where: { $0.id == source.id }) else { return }
        sources[index] = source
    }

    @discardableResult
    func addSource() -> UUID {
        let source = PriceSource(
            label: "New Source",
            apiURL: "https://",
            responseKeyPath: "data.price",
            refreshMilliseconds: 60_000
        )
        sources.append(source)
        return source.id
    }

    func deleteSources(at offsets: IndexSet) {
        let deletableOffsets = offsets.filter { sources[$0].id != selectedSourceID }
        for index in deletableOffsets.sorted(by: >) {
            sources.remove(at: index)
        }

        if sources.isEmpty {
            sources = [.defaultSource]
            selectedSourceID = sources[0].id
        }
    }

    func deleteSource(id: UUID) {
        guard id != selectedSourceID,
              let index = sources.firstIndex(where: { $0.id == id }) else { return }
        sources.remove(at: index)

        if sources.isEmpty {
            sources = [.defaultSource]
            selectedSourceID = sources[0].id
        }
    }

    func moveSourceUp(id sourceID: UUID) {
        guard let index = sources.firstIndex(where: { $0.id == sourceID }),
              index > sources.startIndex else { return }
        var updatedSources = sources
        updatedSources.swapAt(index, updatedSources.index(before: index))
        sources = updatedSources
    }

    func moveSourceDown(id sourceID: UUID) {
        guard let index = sources.firstIndex(where: { $0.id == sourceID }),
              index < sources.index(before: sources.endIndex) else { return }
        var updatedSources = sources
        updatedSources.swapAt(index, updatedSources.index(after: index))
        sources = updatedSources
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(sources) else { return }
        defaults.set(data, forKey: sourcesKey)
        defaults.set(selectedSourceID?.uuidString, forKey: selectedSourceKey)
    }
}
