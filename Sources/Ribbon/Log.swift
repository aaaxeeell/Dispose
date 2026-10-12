import Foundation

/// Plain-text diagnostics in ~/Library/Logs/Ribbon.log (also visible in
/// Console.app). Kept small: truncated at launch.
enum Log {
    static let url = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Logs/Ribbon.log")
    private static var handle: FileHandle?
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
        let line = "\(time.string(from: Date())) \(message)\n"
        handle?.write(line.data(using: .utf8)!)
    }
}
