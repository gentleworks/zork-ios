import Foundation
import Darwin
import UIKit

@Observable
@MainActor
final class GameEngine {

    // MARK: - Singleton

    /// Shared instance — the dungeon C engine uses global state and cannot be
    /// safely instantiated more than once per process lifetime.
    static let shared = GameEngine()

    // MARK: - Public state

    private(set) var outputText: String = ""
    private(set) var isRunning:  Bool   = false
    private(set) var hasEnded:   Bool   = false

    /// Whether the game is saved when leaving the view and restored on return.
    /// Persisted in UserDefaults so the background observer respects it too.
    var autosaveEnabled: Bool = UserDefaults.standard.object(forKey: "zorkAutosave") as? Bool ?? true {
        didSet { UserDefaults.standard.set(autosaveEnabled, forKey: "zorkAutosave") }
    }

    // MARK: - Private state

    private var stdoutReadFD:  Int32 = -1
    private var stdoutWriteFD: Int32 = -1
    private var stdinReadFD:   Int32 = -1
    private var stdinWriteFD:  Int32 = -1
    private var backgroundObserver: NSObjectProtocol?

    // MARK: - Start / Restart

    func start() {
        guard !isRunning else { return }

        var outPipe: [Int32] = [-1, -1]
        Darwin.pipe(&outPipe)
        stdoutReadFD  = outPipe[0]
        stdoutWriteFD = outPipe[1]

        var inPipe: [Int32] = [-1, -1]
        Darwin.pipe(&inPipe)
        stdinReadFD  = inPipe[0]
        stdinWriteFD = inPipe[1]

        configure_dungeon_io(stdoutWriteFD, stdinReadFD)

        copyDataFileIfNeeded()
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        Darwin.chdir(docs.path)

        isRunning = true

        // Autosave on background — registered once for the singleton's lifetime.
        if backgroundObserver == nil {
            backgroundObserver = NotificationCenter.default.addObserver(
                forName: UIApplication.didEnterBackgroundNotification,
                object: nil,
                queue: .main
            ) { _ in
                MainActor.assumeIsolated {
                    GameEngine.shared.autosave()
                }
            }
        }

        let readFD = stdoutReadFD
        Task.detached(priority: .utility) {
            defer { Darwin.close(readFD) }
            var buffer = [UInt8](repeating: 0, count: 4096)
            while true {
                let n = Darwin.read(readFD, &buffer, buffer.count)
                guard n > 0 else { break }
                let chunk = String(bytes: buffer[0..<n], encoding: .utf8) ?? ""
                await MainActor.run {
                    GameEngine.shared.outputText += chunk
                }
            }
        }

        Task.detached(priority: .userInitiated) {
            run_dungeon()
            await MainActor.run {
                GameEngine.shared.isRunning = false
                GameEngine.shared.hasEnded  = true
            }
        }

        // Restore previous session if autosave is on and a save file exists.
        if autosaveEnabled && hasSaveFile() {
            send("restore")
            send("l")
        }
    }

    /// Closes all pipe fds and starts a fresh game. Safe to call after the game ends.
    func restart() {
        // Closing the write end sends EOF to the reader task, which exits via its
        // guard and closes the read end via defer. Stdin fds are closed directly.
        if stdoutWriteFD != -1 { Darwin.close(stdoutWriteFD); stdoutWriteFD = -1 }
        if stdinReadFD   != -1 { Darwin.close(stdinReadFD);   stdinReadFD   = -1 }
        if stdinWriteFD  != -1 { Darwin.close(stdinWriteFD);  stdinWriteFD  = -1 }
        stdoutReadFD = -1   // will be closed by the reader task's defer

        outputText = ""
        isRunning  = false
        hasEnded   = false

        start()
    }

    // MARK: - Save / restore

    /// The hardcoded save file name used by the dungeon C engine (dverb2.c).
    private static let saveFileName = "dsave.dat"

    /// Sends the "save" command if autosave is enabled and the game is running.
    func autosave() {
        guard isRunning && !hasEnded && autosaveEnabled else { return }
        send("save")
    }

    /// Deletes the on-disk save file.
    func deleteSave() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        try? FileManager.default.removeItem(
            at: docs.appendingPathComponent(Self.saveFileName)
        )
    }

    func hasSaveFile() -> Bool {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return FileManager.default.fileExists(
            atPath: docs.appendingPathComponent(Self.saveFileName).path
        )
    }

    // MARK: - Input

    func send(_ command: String) {
        guard isRunning else { return }
        let line = command + "\n"
        line.withCString { ptr in
            let len = strlen(ptr)
            _ = Darwin.write(stdinWriteFD, ptr, len)
        }
    }

    // MARK: - Private helpers

    private func copyDataFileIfNeeded() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dest = docs.appendingPathComponent("dtextc.dat")
        guard !FileManager.default.fileExists(atPath: dest.path) else { return }
        guard let src = Bundle.main.url(forResource: "dtextc", withExtension: "dat") else { return }
        try? FileManager.default.copyItem(at: src, to: dest)
    }
}
