import Combine
import Foundation
import SwiftUI

/// Main pop‑over view that provides a text box for running shell commands.
/// Each command runs in its own long‑lived PTY shell so multiple programs
/// can run concurrently.  A tab bar lets you switch between sessions.
struct ContentView: View {
    // MARK: – Session model

    struct Session: Identifiable {
        let id: UUID
        let shell: Shell
        var log: String = ""
        var title: String
    }

    // MARK: – State

    @State private var command: String = ""
    @State private var sessions: [Session] = []
    @State private var activeSessionID: UUID?
    @State private var scrollTrigger = 0
    @State private var outputObserver: AnyCancellable?

    // MARK: – Body

    var body: some View {
        ScrollViewReader { proxy in
            VStack(spacing: 8) {
                // Tabs
                HStack(spacing: 4) {
                    ForEach(sessions) { session in
                        Button(action: { activeSessionID = session.id }, label: {
                            HStack(spacing: 4) {
                                Text(session.title)
                                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 9))
                                    .onTapGesture { closeSession(session.id) }
                            }
                            .padding(.vertical, 2)
                            .padding(.horizontal, 8)
                            .background(session.id == activeSessionID
                                ? Color.accentColor.opacity(0.3)
                                : Color.gray.opacity(0.2))
                            .cornerRadius(4)
                        })
                        .buttonStyle(PlainButtonStyle())
                    }

                    // New‑session (“+”) button
                    Button(action: { createNewSession() }, label: {
                        Image(systemName: "plus")
                            .font(.system(size: 11, weight: .bold))
                            .padding(4)
                    })
                    .buttonStyle(PlainButtonStyle())
                }

                // Input
                HStack {
                    TextField("Enter shell command…", text: $command)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .onSubmit(runCommand)

                    Button("Run") { runCommand() }
                        .keyboardShortcut(.defaultAction)
                }

                // Log output
                ScrollView {
                    Text(activeSession?.log ?? "")
                        .font(.system(size: 11, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled) // allow copy/select

                    Color.clear
                        .frame(height: 1)
                        .id("BOTTOM")
                }
                .onChange(of: scrollTrigger) { _, _ in
                    withAnimation {
                        proxy.scrollTo("BOTTOM", anchor: .bottom)
                    }
                }
            }
            .padding()
            .frame(minWidth: 700, minHeight: 500)
        }
        .onAppear {
            createInitialSession()
            attachOutputObserver()
        }
    }

    // MARK: – Computed helpers

    private var activeSessionIndex: Int? {
        sessions.firstIndex { $0.id == activeSessionID }
    }

    private var activeSession: Session? {
        guard let idx = activeSessionIndex else { return nil }
        return sessions[idx]
    }

    // MARK: – Actions

    private func createInitialSession() {
        let shell = Shell()
        let sess = Session(id: shell.id, shell: shell, title: "Tab 1")
        sessions = [sess]
        activeSessionID = sess.id
    }

    private func createNewSession() {
        let shell = Shell()
        let title = "Tab \(sessions.count + 1)"
        let sess = Session(id: shell.id, shell: shell, title: title)
        sessions.append(sess)
        activeSessionID = sess.id
    }

    private func closeSession(_ id: UUID) {
        guard let idx = sessions.firstIndex(where: { $0.id == id }) else { return }
        sessions[idx].shell.send("exit")
        sessions.remove(at: idx)

        if sessions.isEmpty {
            createInitialSession()
        } else {
            activeSessionID = sessions.first?.id
        }
    }

    private func runCommand() {
        let trimmed = command.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              let idx = activeSessionIndex else { return }

        sessions[idx].shell.send(trimmed)
        command = ""
    }

    /// Expand tabs (ASCII 9) to the next tab stop so column output like `ls` aligns.
    /// Default tab size is 8, matching most terminals.
    private func expandTabs(_ input: String, tabSize: Int = 8) -> String {
        var result = ""
        var column = 0
        for scalar in input.unicodeScalars {
            if scalar == "\t" {
                let spaces = tabSize - (column % tabSize)
                result.append(String(repeating: " ", count: spaces))
                column += spaces
            } else {
                result.unicodeScalars.append(scalar)
                if scalar == "\n" || scalar == "\r" {
                    column = 0
                } else {
                    column += 1
                }
            }
        }
        return result
    }

    // MARK: – Output handling

    private func attachOutputObserver() {
        outputObserver = NotificationCenter.default.publisher(for: .shellDidOutput)
            .sink { note in
                guard let id = note.userInfo?["id"] as? UUID,
                      let text = note.userInfo?["output"] as? String,
                      let idx = sessions.firstIndex(where: { $0.id == id }) else { return }

                sessions[idx].log.append(expandTabs(text))

                if id == activeSessionID {
                    scrollTrigger += 1
                }
            }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
