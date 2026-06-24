import SwiftUI
import MarkdownUI

struct ContentView: View {
    @StateObject private var vm = ChatViewModel()
    @AppStorage("isDarkMode") private var isDarkMode = true

    var body: some View {
        VStack(spacing: 0) {
            header

            Divider()

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
                }
                .onChange(of: vm.messages.last?.text) { _ in
                    if let last = vm.messages.last {
                        withAnimation(.easeOut(duration: 0.15)) {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
            }

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

    private var inputBar: some View {
        HStack(spacing: 8) {
            TextField("Message Claude…", text: $vm.inputText, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(1...5)
                .onSubmit(vm.sendMessage)
            Button("Send", action: vm.sendMessage)
                .keyboardShortcut(.return, modifiers: .command)
                .disabled(vm.isThinking ||
                          vm.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding()
    }
}

struct MessageRow: View {
    let message: Message

    var body: some View {
        HStack {
            if message.isUser { Spacer(minLength: 48) }

            bubble
                .padding(10)
                .background(message.isUser ? Color.accentColor.opacity(0.25)
                                           : Color.primary.opacity(0.07))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .frame(maxWidth: .infinity,
                       alignment: message.isUser ? .trailing : .leading)

            if !message.isUser { Spacer(minLength: 48) }
        }
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
