import SwiftUI

struct SettingsView: View {
    @ObservedObject var store: PriceSourceStore
    @State private var selectedID: UUID?

    var body: some View {
        HSplitView {
            VStack(spacing: 0) {
                List(selection: $selectedID) {
                    ForEach(store.sources) { source in
                        Text(source.label).tag(source.id)
                    }
                }
                HStack(spacing: 4) {
                    Button(action: addSource) { Image(systemName: "plus") }
                    Button(action: deleteSelectedSource) { Image(systemName: "minus") }
                        .disabled(
                            selectedID == nil
                                || selectedID == store.selectedSourceID
                                || store.sources.count == 1
                        )
                    Spacer()
                }
                .padding(8)
            }
            .frame(minWidth: 220, idealWidth: 240, maxWidth: 300)

            Group {
                if let binding = selectedSourceBinding {
                    PriceSourceForm(source: binding)
                } else {
                    Text("Select a Price Source")
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .frame(minWidth: 460, maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minWidth: 700, minHeight: 420)
        .onAppear { selectedID = store.selectedSourceID }
    }

    private var selectedSourceBinding: Binding<PriceSource>? {
        guard let selectedID,
              let index = store.sources.firstIndex(where: { $0.id == selectedID }) else { return nil }
        return $store.sources[index]
    }

    private func addSource() {
        selectedID = store.addSource()
    }

    private func deleteSelectedSource() {
        guard let selectedID,
              selectedID != store.selectedSourceID,
              let index = store.sources.firstIndex(where: { $0.id == selectedID }) else { return }
        let nextSelection = store.sources.indices
            .filter { $0 != index }
            .min(by: { abs($0 - index) < abs($1 - index) })
            .map { store.sources[$0].id }
        store.deleteSources(at: IndexSet(integer: index))
        self.selectedID = nextSelection
    }
}

private struct PriceSourceForm: View {
    @Binding var source: PriceSource

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            field("Label") {
                TextField("Label", text: $source.label)
            }
            field("API") {
                TextField("https://…", text: $source.apiURL)
            }
            field("Response key path") {
                TextField("data.amount", text: $source.responseKeyPath)
            }
            field("Currency symbol") {
                Picker("Currency symbol", selection: $source.currencySymbol) {
                    ForEach(CurrencySymbol.allCases) { currencySymbol in
                        Text(currencySymbol.label).tag(currencySymbol)
                    }
                }
                .labelsHidden()
                .frame(width: 160)
            }
            field("Refresh interval") {
                HStack {
                    TextField(
                        "Milliseconds",
                        value: $source.refreshMilliseconds,
                        formatter: NumberFormatter.integer
                    )
                    .frame(width: 140)
                    Text("ms").foregroundColor(.secondary)
                    Spacer()
                }
            }
            Text("Nested JSON values use dot notation, for example data.amount. Array indexes are supported, for example data.0.price.")
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
        }
        .textFieldStyle(RoundedBorderTextFieldStyle())
        .padding(24)
    }

    private func field<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.headline)
            content()
        }
    }
}

private extension NumberFormatter {
    static let integer: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .none
        formatter.minimum = 1
        formatter.maximumFractionDigits = 0
        return formatter
    }()
}
