import SwiftUI

struct ContentView: View {

    private let engine = GameEngine.shared
    @State private var command      = ""
    @State private var showSettings = false
    @FocusState private var inputFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                TerminalTextView(text: engine.outputText)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                Divider()
                    .overlay(Color.green.opacity(0.4))

                commandBar
            }
            .background(Color.black)
            .navigationTitle("Dungeon")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showSettings = true } label: {
                        Image(systemName: "gear")
                    }
                    .tint(.green)
                    .accessibilityLabel("Game settings")
                }
            }
            .sheet(isPresented: $showSettings) {
                ZorkSettingsSheet(engine: engine)
            }
            .onAppear {
                engine.start()
                inputFocused = true
            }
            .onDisappear {
                engine.autosave()
            }
            .onChange(of: engine.hasEnded) { _, ended in
                if ended { engine.restart() }
            }
        }
    }

    // MARK: - Command bar

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
        engine.send(trimmed)
        command = ""
    }
}

// MARK: - Settings sheet

private struct ZorkSettingsSheet: View {
    let engine: GameEngine
    @Environment(\.dismiss) private var dismiss
    @State private var showDeleteConfirm = false
    @State private var saveExists        = false

    var body: some View {
        NavigationStack {
            Form {
                // Save / restore
                Section {
                    Toggle("Autosave & Restore", isOn: Binding(
                        get: { engine.autosaveEnabled },
                        set: { engine.autosaveEnabled = $0 }
                    ))
                } header: {
                    Text("Save Game")
                } footer: {
                    Text("When enabled, your progress is saved whenever you leave this screen and restored when you return.")
                }

                if saveExists {
                    Section {
                        Button("Delete Save File", role: .destructive) {
                            showDeleteConfirm = true
                        }
                    } footer: {
                        Text("Removes the saved game. The next session will start a new game.")
                    }
                }

                // How to play
                Section("How to Play") {
                    LabeledContent("Game information") {
                        Text("type **info**")
                            .foregroundStyle(.secondary)
                    }
                    LabeledContent("Commands & instructions") {
                        Text("type **help**")
                            .foregroundStyle(.secondary)
                    }
                }

                // Attribution
                Section {
                    Link(destination: URL(string: "https://github.com/devshane/zork")!) {
                        Label("devshane/zork on GitHub", systemImage: "link")
                    }
                } header: {
                    Text("Acknowledgements")
                } footer: {
                    Text("This game is powered by the public domain C port of Dungeon (Zork 2.6). Thank you to so many people for creating and then making this piece of interactive fiction history freely available.")
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Dungeon Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .confirmationDialog(
                "Delete Save File?",
                isPresented: $showDeleteConfirm,
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    engine.deleteSave()
                    saveExists = false
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Your saved progress will be permanently lost.")
            }
            .onAppear {
                saveExists = engine.hasSaveFile()
            }
        }
    }
}

#Preview {
    ContentView()
}
