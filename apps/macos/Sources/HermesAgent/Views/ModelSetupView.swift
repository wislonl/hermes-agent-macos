import SwiftUI

struct ModelSetupView: View {
    @Bindable var state: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var selectedPreset: ModelPreset = ModelPreset.all[0]
    @State private var apiKey: String = ""
    @State private var validation: ValidationState = .idle
    @State private var isApplying = false
    @State private var configuredKeys: [String: String] = [:]
    @State private var showConfigured = true

    enum ValidationState {
        case idle, testing, valid, invalid(String)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            Text("Add / Update Model")
                .font(.title2.bold())
                .padding([.horizontal, .top], 24)
                .padding(.bottom, 16)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    modelPickerSection
                    keySection
                    configuredSection
                }
                .padding(24)
            }

            Divider()

            // Footer
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button(applyButtonLabel) {
                    Task { await apply() }
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canApply)
                .keyboardShortcut(.return, modifiers: .command)
            }
            .padding(16)
        }
        .frame(width: 460)
        .onAppear { refreshConfiguredKeys() }
    }

    // MARK: - Sections

    @ViewBuilder
    private var modelPickerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Model").font(.headline)

            Menu {
                ForEach(ProviderGroup.allCases, id: \.self) { group in
                    let presets = ModelPreset.presets(for: group)
                    if !presets.isEmpty {
                        Section(group.rawValue) {
                            ForEach(presets) { preset in
                                Button {
                                    selectedPreset = preset
                                    prefillKeyIfConfigured(preset)
                                    validation = .idle
                                } label: {
                                    HStack {
                                        Text(preset.displayName)
                                        if configuredKeys[preset.envKey] != nil {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            } label: {
                HStack {
                    Text(selectedPreset.displayName)
                        .foregroundStyle(.primary)
                    if configuredKeys[selectedPreset.envKey] != nil {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .font(.caption)
                    }
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(Color(.controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color(.separatorColor)))
            }

            Text(selectedPreset.group.rawValue)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var keySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("API Key").font(.headline)

            HStack(spacing: 8) {
                SecureField(selectedPreset.keyHint, text: $apiKey)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))
                    .onChange(of: apiKey) { _, _ in validation = .idle }

                Button {
                    Task { await testKey() }
                } label: {
                    switch validation {
                    case .testing:
                        ProgressView().controlSize(.small).frame(width: 40)
                    default:
                        Text("Test").frame(width: 40)
                    }
                }
                .disabled(apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                          || validation == .testing)
            }

            // Validation feedback
            switch validation {
            case .idle:
                if let existing = configuredKeys[selectedPreset.envKey] {
                    if apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Label("Will switch to \(selectedPreset.displayName) using existing key (\(HermesConfig.maskedKey(existing)))", systemImage: "arrow.trianglehead.2.clockwise")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Label("Will replace existing key (\(HermesConfig.maskedKey(existing)))", systemImage: "checkmark.circle")
                            .font(.caption)
                            .foregroundStyle(.green)
                    }
                } else {
                    Text("Enter key then tap Test to verify before applying.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            case .testing:
                Label("Testing…", systemImage: "network")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            case .valid:
                Label("Key valid", systemImage: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.green)
            case .invalid(let msg):
                Label(msg, systemImage: "xmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            Text("Saved to ~/.hermes/.env as \(selectedPreset.envKey)")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }

    @ViewBuilder
    private var configuredSection: some View {
        let configured = configuredPresets
        if !configured.isEmpty {
            DisclosureGroup(isExpanded: $showConfigured) {
                VStack(spacing: 0) {
                    ForEach(configured, id: \.envKey) { preset in
                        HStack(spacing: 8) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(preset.displayName)
                                    .font(.subheadline)
                                Text(HermesConfig.maskedKey(configuredKeys[preset.envKey] ?? ""))
                                    .font(.caption.monospaced())
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button {
                                deleteKey(preset)
                            } label: {
                                Image(systemName: "trash")
                                    .foregroundStyle(.red.opacity(0.8))
                                    .font(.caption)
                            }
                            .buttonStyle(.borderless)
                            .help("Remove key")
                        }
                        .padding(.vertical, 8)
                        if preset.id != configured.last?.id {
                            Divider()
                        }
                    }
                }
                .padding(.top, 4)
            } label: {
                Text("Configured Keys (\(configured.count))")
                    .font(.headline)
            }
        }
    }

    // MARK: - Helpers

    private var canApply: Bool {
        guard !isApplying else { return false }
        let key = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        if !key.isEmpty { return true }
        return configuredKeys[selectedPreset.envKey] != nil
    }

    private var applyButtonLabel: String {
        let key = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        if key.isEmpty && configuredKeys[selectedPreset.envKey] != nil {
            return "Switch Model & Restart"
        }
        return "Apply & Restart"
    }

    private var configuredPresets: [ModelPreset] {
        // Deduplicate by envKey — show one preset per configured key
        var seen = Set<String>()
        return ModelPreset.all.filter { preset in
            guard configuredKeys[preset.envKey] != nil else { return false }
            return seen.insert(preset.envKey).inserted
        }
    }

    private func prefillKeyIfConfigured(_ preset: ModelPreset) {
        // Don't show actual key value — just clear so user types a new one if needed
        apiKey = ""
    }

    private func refreshConfiguredKeys() {
        configuredKeys = HermesConfig.readConfiguredKeys()
    }

    private func testKey() async {
        let key = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { return }
        guard selectedPreset.validationURL != nil else {
            validation = .valid
            return
        }
        validation = .testing
        let ok = await HermesConfig.validateKey(preset: selectedPreset, apiKey: key)
        validation = ok ? .valid : .invalid("Key rejected (401/403). Check and try again.")
    }

    private func deleteKey(_ preset: ModelPreset) {
        try? HermesConfig.removeEnvKey(preset.envKey)
        refreshConfiguredKeys()
    }

    private func apply() async {
        isApplying = true
        let key = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            if !key.isEmpty {
                try HermesConfig.writeEnvKey(selectedPreset.envKey, value: key)
            }
            try HermesConfig.writeConfigModel(modelId: selectedPreset.modelId, provider: selectedPreset.provider)
            await state.restartRuntime()
            dismiss()
        } catch {
            validation = .invalid(error.localizedDescription)
        }
        isApplying = false
    }
}

extension ModelSetupView.ValidationState: Equatable {
    static func == (lhs: Self, rhs: Self) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.testing, .testing), (.valid, .valid): return true
        case (.invalid(let a), .invalid(let b)): return a == b
        default: return false
        }
    }
}
