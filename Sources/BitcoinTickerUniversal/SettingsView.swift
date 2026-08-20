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
    @State private var isResponsePickerPresented = false
    @State private var isFetchingResponse = false
    @State private var responseFetchFailed = false
    @State private var responseOptions: [ResponseValueOption] = []
    @State private var selectedResponseKeyPath: String?

    private let priceClient = PriceClient()

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            field("Label") {
                TextField("Label", text: $source.label)
            }
            field("API") {
                HStack(spacing: 8) {
                    TextField("https://…", text: $source.apiURL)
                    Button("Fetch") {
                        fetchResponseOptions()
                    }
                }
            }
            field("Response key path") {
                Text(source.responseKeyPath.isEmpty ? "Not selected" : source.responseKeyPath)
                    .foregroundColor(source.responseKeyPath.isEmpty ? .secondary : .primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(
                        RoundedRectangle(cornerRadius: 5)
                            .stroke(Color.secondary.opacity(0.35))
                    )
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
            Text("Use Fetch to inspect the API response and choose a numeric response key path.")
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
        }
        .textFieldStyle(RoundedBorderTextFieldStyle())
        .padding(24)
        .sheet(isPresented: $isResponsePickerPresented) {
            ResponseKeyPathPickerSheet(
                isFetching: isFetchingResponse,
                fetchFailed: responseFetchFailed,
                options: responseOptions,
                selectedKeyPath: $selectedResponseKeyPath,
                onSelect: selectResponseKeyPath,
                onClose: { isResponsePickerPresented = false }
            )
        }
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

    private func fetchResponseOptions() {
        isResponsePickerPresented = true
        isFetchingResponse = true
        responseFetchFailed = false
        responseOptions = []
        selectedResponseKeyPath = nil

        let apiURL = source.apiURL
        Task {
            do {
                let options = try await priceClient.fetchResponseValueOptions(from: apiURL)
                await MainActor.run {
                    responseOptions = options
                    selectedResponseKeyPath = options.first(where: { $0.keyPath == source.responseKeyPath })?.keyPath
                    isFetchingResponse = false
                }
            } catch {
                await MainActor.run {
                    responseFetchFailed = true
                    isFetchingResponse = false
                }
            }
        }
    }

    private func selectResponseKeyPath() {
        guard let selectedResponseKeyPath,
              let option = responseOptions.first(where: { $0.keyPath == selectedResponseKeyPath }) else {
            return
        }

        guard option.isNumeric else { return }

        source.responseKeyPath = selectedResponseKeyPath
        isResponsePickerPresented = false
    }
}

private struct ResponseKeyPathPickerSheet: View {
    let isFetching: Bool
    let fetchFailed: Bool
    let options: [ResponseValueOption]
    @Binding var selectedKeyPath: String?
    let onSelect: () -> Void
    let onClose: () -> Void

    private var selectedOption: ResponseValueOption? {
        guard let selectedKeyPath else { return nil }
        return options.first(where: { $0.keyPath == selectedKeyPath })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Select Response Key Path")
                .font(.title3)
                .fontWeight(.semibold)

            if isFetching {
                HStack(spacing: 10) {
                    ProgressView()
                    Text("Fetching response…")
                        .foregroundColor(.secondary)
                }
                .frame(width: 520, height: 220)
            } else if fetchFailed {
                Text("Failed to fetch data. Check the url agian.")
                    .foregroundColor(.secondary)
                    .frame(width: 520)
                    .frame(minHeight: 120, alignment: .center)
                HStack {
                    Spacer()
                    Button("Close", action: onClose)
                        .keyboardShortcut(.cancelAction)
                }
            } else {
                if options.isEmpty {
                    Text("No selectable response values found.")
                        .foregroundColor(.secondary)
                        .frame(width: 520)
                        .frame(minHeight: 120, alignment: .center)
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 2) {
                            ForEach(options) { option in
                                ResponseValueOptionRow(
                                    option: option,
                                    isSelected: selectedKeyPath == option.keyPath,
                                    action: {
                                        if option.isNumeric {
                                            selectedKeyPath = option.keyPath
                                        }
                                    }
                                )
                            }
                        }
                    }
                    .frame(width: 560, height: 320)
                    .background(Color(NSColor.textBackgroundColor))
                    .overlay(
                        RoundedRectangle(cornerRadius: 5)
                            .stroke(Color.secondary.opacity(0.25))
                    )
                }

                HStack {
                    Spacer()
                    Button("Close", action: onClose)
                        .keyboardShortcut(.cancelAction)
                    Button("Select", action: onSelect)
                        .keyboardShortcut(.defaultAction)
                        .disabled(selectedOption?.isNumeric != true)
                }
            }
        }
        .padding(20)
    }
}

private struct ResponseValueOptionRow: View {
    let option: ResponseValueOption
    let isSelected: Bool
    let action: () -> Void

    private var depth: Int {
        guard option.keyPath != "$" else { return 0 }
        return max(option.keyPath.split(separator: ".").count - 1, 0)
    }

    var body: some View {
        Button(action: action) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                    .foregroundColor(option.isNumeric ? .accentColor : Color.secondary.opacity(0.45))
                VStack(alignment: .leading, spacing: 2) {
                    Text(option.keyPath)
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(option.isNumeric ? .primary : Color.secondary.opacity(0.6))
                    Text(option.displayValue)
                        .font(.caption)
                        .foregroundColor(option.isNumeric ? .orange : Color.secondary.opacity(0.6))
                        .lineLimit(1)
                }
                Spacer()
            }
            .contentShape(Rectangle())
            .padding(.leading, CGFloat(depth) * 16)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(!option.isNumeric)
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
