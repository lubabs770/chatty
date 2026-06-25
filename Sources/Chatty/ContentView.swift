import SwiftUI
import AppKit
import MarkdownUI

struct ContentView: View {
    @StateObject private var vm = ChatViewModel()
    @AppStorage("isDarkMode") private var isDarkMode = true

    // Input field auto-grow: the NSTextView reports its laid-out height here,
    // and we clamp it between one line and `maxInputHeight` (scrolling past).
    @State private var inputHeight: CGFloat = 22
    private let minInputHeight: CGFloat = 22
    private let maxInputHeight: CGFloat = 140

    // Auto-scroll lives only while the user stays parked at the bottom. The
    // moment they scroll up mid-stream we stop yanking them back down.
    @State private var isPinnedToBottom = true

    var body: some View {
        VStack(spacing: 0) {
            header

            Divider()

            transcript

            Divider()

            inputBar
        }
        .frame(minWidth: 520, minHeight: 640)
        .preferredColorScheme(isDarkMode ? .dark : .light)
    }

    private var header: some View {
        HStack {
            Text("Chatty").font(.headline)
            Spacer()
            Button {
                isDarkMode.toggle()
            } label: {
                Image(systemName: isDarkMode ? "sun.max.fill" : "moon.fill")
            }
            .buttonStyle(.borderless)
            .help(isDarkMode ? "Switch to light mode" : "Switch to dark mode")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
    }

    private var transcript: some View {
        GeometryReader { outer in
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        ForEach(vm.messages) { msg in
                            MessageRow(message: msg).id(msg.id)
                        }
                        if vm.isThinking, vm.messages.last?.text.isEmpty ?? false {
                            HStack(spacing: 6) {
                                ProgressView().controlSize(.small)
                                Text("Thinking…").foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding()
                    .background(
                        // Distance from the content's bottom edge to the
                        // viewport's bottom edge. ~0 means parked at the bottom.
                        GeometryReader { inner in
                            Color.clear.preference(
                                key: BottomDistanceKey.self,
                                value: inner.frame(in: .named("transcript")).maxY - outer.size.height
                            )
                        }
                    )
                }
                .coordinateSpace(name: "transcript")
                .onPreferenceChange(BottomDistanceKey.self) { distance in
                    isPinnedToBottom = distance <= 24
                }
                .onChange(of: vm.messages.last?.text) { _ in
                    if isPinnedToBottom { scrollToBottom(proxy) }
                }
                .onChange(of: vm.messages.count) { _ in
                    // A brand-new turn (the user's own message) always snaps down.
                    if vm.messages.last?.isUser == true {
                        isPinnedToBottom = true
                        scrollToBottom(proxy)
                    }
                }
            }
        }
    }

    private func scrollToBottom(_ proxy: ScrollViewProxy) {
        guard let last = vm.messages.last else { return }
        withAnimation(.easeOut(duration: 0.15)) {
            proxy.scrollTo(last.id, anchor: .bottom)
        }
    }

    private var inputBar: some View {
        HStack(alignment: .bottom, spacing: 8) {
            ZStack(alignment: .topLeading) {
                if vm.inputText.isEmpty {
                    Text("Message Claude…")
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 7)
                        .allowsHitTesting(false)
                }
                MessageInput(
                    text: $vm.inputText,
                    calculatedHeight: $inputHeight,
                    onSubmit: vm.sendMessage
                )
                .frame(height: min(max(inputHeight, minInputHeight), maxInputHeight))
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.primary.opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.primary.opacity(0.12), lineWidth: 1)
            )

            Button("Send", action: vm.sendMessage)
                .keyboardShortcut(.return, modifiers: .command)
                .disabled(vm.isThinking ||
                          vm.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding()
    }
}

/// Reports how far the transcript's bottom edge sits below the viewport bottom.
private struct BottomDistanceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}

struct MessageRow: View {
    let message: Message
    @State private var didCopy = false

    var body: some View {
        VStack(alignment: message.isUser ? .trailing : .leading, spacing: 3) {
            HStack {
                if message.isUser { Spacer(minLength: 48) }

                bubble
                    .padding(10)
                    .background(message.isUser ? Color.accentColor.opacity(0.25)
                                               : Color.primary.opacity(0.07))
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                if !message.isUser { Spacer(minLength: 48) }
            }

            copyButton
                .padding(message.isUser ? .trailing : .leading, 2)
        }
        .frame(maxWidth: .infinity,
               alignment: message.isUser ? .trailing : .leading)
    }

    private var copyButton: some View {
        Button {
            copyToClipboard(message.text)
        } label: {
            Image(systemName: didCopy ? "checkmark" : "doc.on.doc")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
        .buttonStyle(.borderless)
        .help("Copy to clipboard")
        // Hide the control until the bubble has content worth copying.
        .opacity(message.text.isEmpty ? 0 : 1)
        .disabled(message.text.isEmpty)
    }

    private func copyToClipboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        didCopy = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { didCopy = false }
    }

    @ViewBuilder private var bubble: some View {
        if message.isUser {
            // User text is literal — show it verbatim, no markdown parsing.
            Text(message.text).textSelection(.enabled)
        } else {
            // Assistant replies render as GitHub-flavored markdown. The default
            // MarkdownUI theme uses .primary colors, so it adapts to dark/light.
            Markdown(message.text.isEmpty ? " " : message.text)
                .textSelection(.enabled)
        }
    }
}
