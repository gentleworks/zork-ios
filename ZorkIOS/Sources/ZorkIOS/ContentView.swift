import SwiftUI

struct ContentView: View {

    @State private var engine = GameEngine()
    @State private var command: String = ""
    @FocusState private var inputFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            terminalOutput
            Divider()
            commandBar
        }
        .background(Color.black)
        .onAppear {
            engine.start()
            inputFocused = true
        }
    }

    // MARK: - Subviews

    private var terminalOutput: some View {
        TerminalTextView(text: engine.outputText)
    }

    private var commandBar: some View {
        HStack(spacing: 8) {
            Text(">")
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(.green)

            TextField("", text: $command)
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(.green)
                .tint(.green)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled(true)
                .focused($inputFocused)
                .onSubmit(sendCommand)
                .disabled(engine.hasEnded)

            if !command.isEmpty {
                Button(action: sendCommand) {
                    Image(systemName: "return")
                        .foregroundStyle(.green)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.black)
    }

    // MARK: - Actions

    private func sendCommand() {
        let trimmed = command.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        // Echo the command into the output so the player sees what they typed
        engine.send(trimmed)
        command = ""
    }
}

#Preview {
    ContentView()
}
