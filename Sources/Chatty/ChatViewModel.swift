import Foundation

@MainActor
final class ChatViewModel: ObservableObject {
    @Published var messages: [Message] = []
    @Published var inputText: String = ""
    @Published var isThinking: Bool = false

    /// Set once we've started a conversation, so follow-up turns keep context.
    private var sessionId: String?

    // Resolve the claude binary once. Extend if you move installs around.
    private static let claudePath: String = {
        let candidates = [
            "\(NSHomeDirectory())/.local/bin/claude",
            "/opt/homebrew/bin/claude",
            "/usr/local/bin/claude",
        ]
        return candidates.first { FileManager.default.isExecutableFile(atPath: $0) } ?? "claude"
    }()

    /// Directory claude runs in (what it can see/touch). Defaults to home.
    private static let workingDirectory = NSHomeDirectory()

    /// How tool-use permissions are handled. There's no interactive approval
    /// in this UI, so anything stricter than `bypassPermissions` means tool
    /// calls (web search, file reads, bash) get auto-denied mid-turn.
    ///   "bypassPermissions" – all tools run, no prompts (powerful: can edit
    ///                         files / run bash in workingDirectory)
    ///   "default"           – conversation only; tool calls are declined
    ///   "acceptEdits"       – auto-approves edits, still declines bash/search
    private static let permissionMode = "bypassPermissions"

    func sendMessage() {
        let prompt = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prompt.isEmpty, !isThinking else { return }

        messages.append(Message(text: prompt, isUser: true))
        inputText = ""
        isThinking = true

        // Empty assistant bubble we stream tokens into as they arrive.
        let placeholder = Message(text: "", isUser: false)
        messages.append(placeholder)
        let assistantId = placeholder.id

        Task { await stream(prompt: prompt, assistantId: assistantId) }
    }

    private func stream(prompt: String, assistantId: UUID) async {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: Self.claudePath)

        // No shell, no string interpolation -> no injection, no escaping needed.
        var args = [
            "-p", prompt,
            "--output-format", "stream-json",
            "--include-partial-messages",
            "--verbose",                       // required by stream-json
            "--permission-mode", Self.permissionMode,
        ]
        if let sessionId { args += ["--resume", sessionId] }
        process.arguments = args

        // Run somewhere real instead of inheriting the launcher's cwd (which is
        // "/" when opened from Finder). This is what claude can see and edit.
        process.currentDirectoryURL = URL(fileURLWithPath: Self.workingDirectory)

        // GUI apps launched outside a terminal get a bare PATH. Give claude a real one.
        var env = ProcessInfo.processInfo.environment
        env["PATH"] = "\(NSHomeDirectory())/.local/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin"
        process.environment = env

        let outPipe = Pipe()
        let errPipe = Pipe()
        process.standardOutput = outPipe
        process.standardError = errPipe
        process.standardInput = FileHandle.nullDevice  // never block waiting on stdin

        do {
            try process.run()
        } catch {
            append(to: assistantId, text: "Failed to launch claude at \(Self.claudePath): \(error.localizedDescription)")
            isThinking = false
            return
        }

        // Read JSONL line-by-line as it streams. The async sequence drains the
        // pipe off-thread and suspends between lines, so the UI stays live and
        // the pipe never deadlocks.
        do {
            for try await line in outPipe.fileHandleForReading.bytes.lines {
                handle(line: line, assistantId: assistantId)
            }
        } catch {
            // Stream interrupted; fall through to termination handling below.
        }

        process.waitUntilExit()
        isThinking = false

        if currentText(of: assistantId).isEmpty {
            if process.terminationStatus != 0 {
                let err = String(data: errPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
                append(to: assistantId, text: "claude exited \(process.terminationStatus): \(err.trimmingCharacters(in: .whitespacesAndNewlines))")
            } else {
                append(to: assistantId, text: "(no response)")
            }
        }
    }

    private func handle(line: String, assistantId: UUID) {
        guard let data = line.data(using: .utf8),
              let event = try? JSONDecoder().decode(StreamLine.self, from: data) else { return }

        // session_id shows up on the init and result events; grab it for --resume.
        if let sid = event.session_id { sessionId = sid }

        // Live text tokens arrive as Anthropic streaming deltas.
        if event.type == "stream_event",
           event.event?.type == "content_block_delta",
           event.event?.delta?.type == "text_delta",
           let chunk = event.event?.delta?.text {
            append(to: assistantId, text: chunk)
        }
    }

    // MARK: - Message mutation helpers

    private func index(of id: UUID) -> Int? { messages.firstIndex { $0.id == id } }
    private func currentText(of id: UUID) -> String { index(of: id).map { messages[$0].text } ?? "" }
    private func append(to id: UUID, text: String) {
        guard let i = index(of: id) else { return }
        messages[i].text += text
    }
}

// MARK: - stream-json line schema (only the fields we care about)

private struct StreamLine: Decodable {
    let type: String
    let session_id: String?
    let event: StreamEvent?
}

private struct StreamEvent: Decodable {
    let type: String?
    let delta: Delta?
}

private struct Delta: Decodable {
    let type: String?
    let text: String?
}
