import SwiftUI

struct InspectorView: View {
    @Bindable var state: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            modelSection

            Divider()

            toolCallsSection

            Spacer()

            connectionFooter
        }
        .padding()
        .frame(minWidth: 240)
    }

    @ViewBuilder
    private var modelSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Model").font(.headline)
            if state.availableModels.isEmpty {
                Text("Model list will appear once a session is active.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Picker("Model", selection: Binding(
                    get: { state.currentModelId ?? state.availableModels.first?.id ?? "" },
                    set: { newId in
                        guard newId != state.currentModelId else { return }
                        Task { await state.setModel(newId) }
                    }
                )) {
                    ForEach(state.availableModels) { model in
                        Text(model.name).tag(model.id)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()

                if let current = state.availableModels.first(where: { $0.id == state.currentModelId }),
                   let description = current.description {
                    Text(description)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
        }
    }

    @ViewBuilder
    private var toolCallsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Tool calls").font(.headline)
                Spacer()
                if !state.toolCalls.isEmpty {
                    Button {
                        state.clearToolCalls()
                    } label: {
                        Image(systemName: "trash")
                            .font(.caption)
                    }
                    .buttonStyle(.borderless)
                    .foregroundStyle(.secondary)
                    .help("Clear tool calls")
                }
            }
            if state.toolCalls.isEmpty {
                ContentUnavailableView(
                    "No tool calls yet",
                    systemImage: "wrench.and.screwdriver"
                )
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                List(state.toolCalls) { call in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            statusIcon(for: call.status)
                            Text(call.title).font(.subheadline.bold())
                        }
                        if !call.detail.isEmpty {
                            Text(call.detail)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(6)
                                .textSelection(.enabled)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .listStyle(.plain)
                .frame(maxHeight: 320)
            }
        }
    }

    @ViewBuilder
    private var connectionFooter: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(connectionColor)
                .frame(width: 8, height: 8)
            Text(state.statusMessage)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
    }

    private var connectionColor: Color {
        switch state.connectionState {
        case .ready: return .green
        case .starting: return .yellow
        case .failed, .disconnected: return .red
        }
    }

    private func statusIcon(for status: ToolCallView.Status) -> some View {
        let (name, tint): (String, Color)
        switch status {
        case .pending:   (name, tint) = ("circle.dotted", .secondary)
        case .running:   (name, tint) = ("circle.dashed", .blue)
        case .completed: (name, tint) = ("checkmark.circle.fill", .green)
        case .failed:    (name, tint) = ("xmark.circle.fill", .red)
        }
        return Image(systemName: name).foregroundStyle(tint)
    }
}
