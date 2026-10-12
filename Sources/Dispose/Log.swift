import Foundation

/// Plain-text diagnostics in ~/Library/Logs/Dispose.log (also visible in
/// Console.app). Kept small: truncated at launch.
enum Log {
    static let url = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Logs/Dispose.log")
    private static var handle: FileHandle?
    private static let lock = NSLock()
    private static let time: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss.SSS"
        return f
    }()

    static func start() {
        FileManager.default.createFile(atPath: url.path, contents: nil)
        handle = try? FileHandle(forWritingTo: url)
    }

    static func write(_ message: String) {
        lock.lock()
        defer { lock.unlock() }
        let line = "\(time.string(from: Date())) \(message)\n"
        handle?.write(line.data(using: .utf8)!)
    }
}
