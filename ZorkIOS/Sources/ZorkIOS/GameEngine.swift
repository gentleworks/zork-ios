import Foundation
import Darwin

@Observable
@MainActor
final class GameEngine {

    // MARK: - Public state

    /// Accumulated game output displayed in the terminal view.
    private(set) var outputText: String = ""

    /// True while the game loop is running.
    private(set) var isRunning: Bool = false

    /// True after the game has exited (won, died, quit).
    private(set) var hasEnded: Bool = false

    // MARK: - Private pipe file descriptors

    private var stdoutReadFD:  Int32 = -1
    private var stdoutWriteFD: Int32 = -1
    private var stdinReadFD:   Int32 = -1
    private var stdinWriteFD:  Int32 = -1

    // MARK: - Start

    func start() {
        guard !isRunning else { return }

        // Create stdout pipe: game writes to [1], we read from [0]
        var outPipe: [Int32] = [-1, -1]
        Darwin.pipe(&outPipe)
        stdoutReadFD  = outPipe[0]
        stdoutWriteFD = outPipe[1]

        // Create stdin pipe: we write to [1], game reads from [0]
        var inPipe: [Int32] = [-1, -1]
        Darwin.pipe(&inPipe)
        stdinReadFD  = inPipe[0]
        stdinWriteFD = inPipe[1]

        // Tell the bridge which fds to use. run_dungeon() will dup2 stdin
        // itself; stdout is captured via the putchar/printf overrides in
        // ios_bridge.c (never touches STDOUT_FILENO).
        configure_dungeon_io(stdoutWriteFD, stdinReadFD)

        // Prepare the game data file and set working directory
        copyDataFileIfNeeded()
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        Darwin.chdir(docs.path)

        isRunning = true

        // Launch output reader — runs until the write end of the pipe closes
        let readFD = stdoutReadFD
        Task.detached(priority: .utility) { [weak self] in
            var buffer = [UInt8](repeating: 0, count: 4096)
            while true {
                let n = Darwin.read(readFD, &buffer, buffer.count)
                guard n > 0 else { break }
                let chunk = String(bytes: buffer[0..<n], encoding: .utf8) ?? ""
                await MainActor.run {
                    self?.outputText += chunk
                }
            }
        }

        // Launch the game on a background thread
        Task.detached(priority: .userInitiated) { [weak self] in
            run_dungeon()   // blocks until game exits
            await MainActor.run {
                self?.isRunning = false
                self?.hasEnded = true
            }
        }
    }

    // MARK: - Input

    /// Send a command line to the game (newline appended automatically).
    func send(_ command: String) {
        guard isRunning else { return }
        let line = command + "\n"
        line.withCString { ptr in
            let len = strlen(ptr)
            _ = Darwin.write(stdinWriteFD, ptr, len)
        }
    }

    // MARK: - Helpers

    private func copyDataFileIfNeeded() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dest = docs.appendingPathComponent("dtextc.dat")
        guard !FileManager.default.fileExists(atPath: dest.path) else { return }
        guard let src = Bundle.main.url(forResource: "dtextc", withExtension: "dat") else {
            print("ZorkIOS: dtextc.dat not found in bundle")
            return
        }
        do {
            try FileManager.default.copyItem(at: src, to: dest)
        } catch {
            print("ZorkIOS: failed to copy dtextc.dat: \(error)")
        }
    }
}
