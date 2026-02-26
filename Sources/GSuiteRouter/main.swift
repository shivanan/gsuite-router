import AppKit

struct CommandLineHandler {
    static func handleArguments() {
        guard let restoreIndex = CommandLine.arguments.firstIndex(of: "--restore") else { return }
        let targets = CommandLine.arguments.suffix(from: CommandLine.arguments.index(after: restoreIndex))
        if targets.isEmpty {
            fputs("Usage: GSuiteRouter --restore /path/to/file.gdoc [...]\n", stderr)
            exit(1)
        }
        var failures = false
        for target in targets {
            let url = URL(fileURLWithPath: target)
            do {
                let restoredURL = try FileUtilities.restoreOriginal(from: url)
                print("Restored \(restoredURL.path)")
            } catch {
                failures = true
                fputs("Failed to restore \(target): \(error)\n", stderr)
            }
        }
        exit(failures ? 1 : 0)
    }
}

CommandLineHandler.handleArguments()

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.regular)
app.run()
