import Foundation
import Darwin

/// Represents a long‑running login shell inside a pseudo‑terminal (PTY).
/// The menu‑bar UI sends commands to this shell, and any output is dispatched
/// as `Notification.Name.shellDidOutput` containing a `String`.
class Shell {
    private let masterFD: Int32
    private let task: Process
    private let readerQueue = DispatchQueue(label: "shell.reader", qos: .background)
    let id = UUID()

    init() {
        var master: Int32 = 0
        var slave: Int32 = 0
        // openpty gives us a fully‑configured PTY pair.
        guard openpty(&master, &slave, nil, nil, nil) == 0 else {
            fatalError("openpty failed")
        }
        masterFD = master

        // Launch a login zsh so we inherit full environment (PATH, brew, etc.)
        task = Process()
        task.launchPath = "/bin/zsh"
        task.arguments = ["-l", "-i"]   // login *and* interactive
        task.currentDirectoryPath = NSHomeDirectory()  // start in the user’s home folder
        // Extend PATH so brew & other Homebrew binaries resolve even if dot‑files fail
        var env = ProcessInfo.processInfo.environment
        if let existing = env["PATH"] {
            if !existing.contains("/usr/local/bin") {
                env["PATH"] = existing + ":/usr/local/bin"
            }
            if !existing.contains("/opt/homebrew/bin") {
                env["PATH"] = env["PATH"]! + ":/opt/homebrew/bin"
            }
        } else {
            env["PATH"] = "/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin"
        }
        task.environment = env
        task.standardInput  = FileHandle(fileDescriptor: slave)
        task.standardOutput = FileHandle(fileDescriptor: slave)
        task.standardError  = FileHandle(fileDescriptor: slave)
        task.launch()

        // Start a background reader that forwards shell output to the main thread.
        readerQueue.async { [weak self] in
            let fh = FileHandle(fileDescriptor: master)
            while let strongSelf = self, strongSelf.task.isRunning {
                let data = fh.availableData
                if data.isEmpty { break }
                if let str = String(data: data, encoding: .utf8) {
                    print(str, terminator: "")
                    DispatchQueue.main.async {
                        NotificationCenter.default.post(name: .shellDidOutput,
                                                        object: nil,
                                                        userInfo: ["id": strongSelf.id,
                                                                   "output": str])
                    }
                }
            }
        }
    }

    /// Send a line to the shell.
    func send(_ line: String) {
        let cmd = line + "\n"
        cmd.withCString { ptr in
            _ = write(masterFD, ptr, strlen(ptr))
        }
    }
}

extension Notification.Name {
    static let shellDidOutput = Notification.Name("shellDidOutput")
}
