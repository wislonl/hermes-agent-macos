import SwiftUI

struct ConversationView: View {
    @Bindable var state: AppState
    @FocusState private var inputFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        ForEach(state.messages) { message in
                            messageRow(message)
                                .id(message.id)
                        }
                    }
                    .padding()
                }
                .onChange(of: state.messages.last?.id) { _, newValue in
                    guard let id = newValue else { return }
                    withAnimation(.easeOut(duration: 0.15)) {
                        proxy.scrollTo(id, anchor: .bottom)
                    }
                }
            }

            Divider()

            HStack(alignment: .center, spacing: 8) {
                TextField("Ask Hermes (Shift+Return for newline)", text: $state.draft, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(1...6)
                    .focused($inputFocused)
                    .onKeyPress(.return, phases: .down) { press in
                        guard !press.modifiers.contains(.shift) else { return .ignored }
                        state.submitDraft()
                        return .handled
                    }
                    .disabled(state.connectionState != .ready)

                if state.isAwaitingResponse {
                    Button {
                        Task { await state.cancelCurrentRun() }
                    } label: {
                        Label("Stop", systemImage: "stop.circle")
                    }
                } else {
                    Button {
                        state.submitDraft()
                    } label: {
                        Label("Send", systemImage: "paperplane.fill")
                    }
                    .keyboardShortcut(.return, modifiers: [.command])
                    .disabled(state.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                              || state.connectionState != .ready)
                }
            }
            .padding(12)
            .background(.bar)
        }
        .navigationTitle("Conversation")
        .onAppear { inputFocused = true }
    }

    @ViewBuilder
    private func messageRow(_ message: ChatMessage) -> some View {
        let isUser = message.author == .user
        VStack(alignment: isUser ? .trailing : .leading, spacing: 4) {
            Text(message.author.displayName)
                .font(.caption)
                .foregroundStyle(.secondary)

            Group {
                if message.author == .agent {
                    if message.text.isEmpty {
                        Text("…").foregroundStyle(.secondary)
                    } else {
                        MarkdownContent(text: message.text)
                    }
                } else {
                    Text(message.text)
                        .textSelection(.enabled)
                }
            }
            .padding(10)
            .background(background(for: message.author))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .frame(maxWidth: .infinity, alignment: isUser ? .trailing : .leading)
    }

    private func background(for author: ChatMessage.Author) -> Color {
        switch author {
        case .user: return Color.accentColor.opacity(0.12)
        case .agent: return Color.secondary.opacity(0.10)
        case .system: return Color.orange.opacity(0.10)
        }
    }
}

// MARK: - Markdown renderer (no third-party dependency)

private struct MarkdownContent: View {
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(segments.enumerated()), id: \.offset) { _, segment in
                switch segment {
                case .prose(let content):
                    if let attr = try? AttributedString(
                        markdown: content,
                        options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
                    ) {
                        Text(attr)
                            .textSelection(.enabled)
                    } else {
                        Text(content)
                            .textSelection(.enabled)
                    }
                case .code(let lang, let content):
                    VStack(alignment: .leading, spacing: 0) {
                        if let lang, !lang.isEmpty {
                            Text(lang)
                                .font(.system(.caption2, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 8)
                                .padding(.top, 6)
                        }
                        ScrollView(.horizontal, showsIndicators: false) {
                            Text(content)
                                .font(.system(.caption, design: .monospaced))
                                .textSelection(.enabled)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 6)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .background(Color(.textBackgroundColor).opacity(0.6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
            }
        }
    }

    private enum Segment {
        case prose(String)
        case code(lang: String?, content: String)
    }

    private var segments: [Segment] {
        var result: [Segment] = []
        var remaining = text
        let fence = "```"

        while let openRange = remaining.range(of: fence) {
            let before = String(remaining[remaining.startIndex..<openRange.lowerBound])
            if !before.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                result.append(.prose(before.trimmingCharacters(in: .newlines)))
            }
            let afterFence = remaining[openRange.upperBound...]
            let langEnd = afterFence.firstIndex(of: "\n") ?? afterFence.endIndex
            let lang = String(afterFence[afterFence.startIndex..<langEnd]).trimmingCharacters(in: .whitespaces)
            let codeStart = langEnd < afterFence.endIndex ? afterFence.index(after: langEnd) : afterFence.endIndex
            let rest = String(afterFence[codeStart...])
            if let closeRange = rest.range(of: fence) {
                let code = String(rest[rest.startIndex..<closeRange.lowerBound])
                result.append(.code(lang: lang.isEmpty ? nil : lang, content: code))
                remaining = String(rest[closeRange.upperBound...])
                if remaining.hasPrefix("\n") { remaining = String(remaining.dropFirst()) }
            } else {
                result.append(.code(lang: lang.isEmpty ? nil : lang, content: rest))
                remaining = ""
            }
        }

        if !remaining.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            result.append(.prose(remaining.trimmingCharacters(in: .newlines)))
        }
        return result
    }
}

private extension ChatMessage.Author {
    var displayName: String {
        switch self {
        case .user: "You"
        case .agent: "Hermes"
        case .system: "System"
        }
    }
}
