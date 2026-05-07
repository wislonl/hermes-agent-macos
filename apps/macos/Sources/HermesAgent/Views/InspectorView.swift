import SwiftUI

struct InspectorView: View {
    @Bindable var state: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Run Inspector").font(.title3).bold()
            providerConfiguration

            if state.toolCalls.isEmpty {
                ContentUnavailableView("No tool calls yet", systemImage: "wrench.and.screwdriver")
            } else {
                List(state.toolCalls) { call in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: call.requiresApproval ? "exclamationmark.triangle.fill" : "terminal")
                            .foregroundStyle(call.requiresApproval ? .orange : .secondary)
                            .frame(width: 18)

                        VStack(alignment: .leading, spacing: 6) {
                            Text(call.title).font(.headline)
                            Text(call.detail).font(.caption).foregroundStyle(.secondary)
                            if call.requiresApproval {
                                let approval = state.approvals.first { $0.id == call.approvalId }
                                let decision = approval?.decision

                                Label(statusText(for: decision), systemImage: "lock")
                                    .foregroundStyle(statusColor(for: decision))

                                if decision == nil {
                                    HStack(spacing: 8) {
                                        Button("Approve") {
                                            resolve(call, as: .approved)
                                        }
                                        Button("Deny", role: .destructive) {
                                            resolve(call, as: .denied)
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .padding()
        .frame(minWidth: 280)
    }

    private var providerConfiguration: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Provider").font(.headline)

            Picker("Provider", selection: $state.selectedProvider) {
                ForEach(ProviderSelection.allCases) { provider in
                    Text(provider.displayName).tag(provider)
                }
            }
            .pickerStyle(.menu)
            .onChange(of: state.selectedProvider) {
                state.applyProviderPreset()
            }

            switch state.selectedProvider {
            case .echo:
                EmptyView()
            case .deepSeek, .openAI, .openRouter, .together, .fireworks, .groq, .moonshot, .qwen, .zhipu, .minimax, .minimaxChina, .volcengineArk, .ollama, .openAICompatible:
                if let preset = ProviderPreset.preset(for: state.selectedProvider), preset.models.count > 1 {
                    Picker("Model", selection: $state.providerModelDraft) {
                        ForEach(preset.models, id: \.self) { model in
                            Text(model).tag(model)
                        }
                    }
                    .pickerStyle(.menu)
                } else {
                    TextField("Model", text: $state.providerModelDraft)
                        .textFieldStyle(.roundedBorder)
                }

                TextField("Base URL", text: $state.providerBaseURLDraft)
                    .textFieldStyle(.roundedBorder)
                if ProviderPreset.preset(for: state.selectedProvider)?.requiresAPIKey != false {
                    SecureField("API key", text: $state.providerAPIKeyDraft)
                        .textFieldStyle(.roundedBorder)
                    HStack(spacing: 8) {
                        Label(
                            state.providerAPIKeyIsSaved ? "Key saved" : "No key saved",
                            systemImage: state.providerAPIKeyIsSaved ? "checkmark.circle" : "key"
                        )
                        .font(.caption)
                        .foregroundStyle(state.providerAPIKeyIsSaved ? .green : .secondary)

                        if state.providerAPIKeyIsSaved {
                            Button("Clear Key", role: .destructive) {
                                clearProviderAPIKey()
                            }
                            .font(.caption)
                        }
                    }
                }
            }

            HStack {
                Button("Save Provider") {
                    saveProviderConfiguration()
                }
                .disabled(!canSaveProvider)
                Button("Test") {
                    Task {
                        await state.testProviderConfiguration()
                    }
                }
                .disabled(!canTestProvider || state.isTestingProvider)
                Text(state.providerStatusMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.bottom, 8)
    }

    private var canSaveProvider: Bool {
        switch state.selectedProvider {
        case .echo:
            true
        case .deepSeek, .openAI, .openRouter, .together, .fireworks, .groq, .moonshot, .qwen, .zhipu, .minimax, .minimaxChina, .volcengineArk, .openAICompatible:
            !state.providerBaseURLDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                && !state.providerModelDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                && (!state.providerAPIKeyDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || state.providerAPIKeyIsSaved)
        case .ollama:
            !state.providerBaseURLDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                && !state.providerModelDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    private var canTestProvider: Bool {
        switch state.selectedProvider {
        case .echo:
            true
        case .deepSeek, .openAI, .openRouter, .together, .fireworks, .groq, .moonshot, .qwen, .zhipu, .minimax, .minimaxChina, .volcengineArk, .ollama, .openAICompatible:
            !state.providerBaseURLDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                && !state.providerModelDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    private func resolve(_ call: ToolCall, as decision: ApprovalDecision) {
        guard let approvalId = call.approvalId else { return }
        state.resolveApproval(id: approvalId, decision: decision)
    }

    private func saveProviderConfiguration() {
        do {
            try state.saveProviderConfiguration()
        } catch {
            state.providerStatusMessage = "Could not save provider."
        }
    }

    private func clearProviderAPIKey() {
        do {
            try state.clearProviderAPIKey()
        } catch {
            state.providerStatusMessage = "Could not clear provider API key."
        }
    }

    private func statusText(for decision: ApprovalDecision?) -> String {
        switch decision {
        case .approved:
            "Approved"
        case .denied:
            "Denied"
        case nil:
            "Pending"
        }
    }

    private func statusColor(for decision: ApprovalDecision?) -> Color {
        switch decision {
        case .approved:
            .green
        case .denied:
            .red
        case nil:
            .orange
        }
    }
}
