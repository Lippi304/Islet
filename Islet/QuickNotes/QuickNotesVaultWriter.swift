import Foundation

// Phase 64 (D-06/D-07) — append-only writer for the user's Obsidian vault .md file.
// Never reads or rewrites the whole file: readTail() loads only the last windowBytes
// bytes to decide whether today's day heading already exists, then the write is a
// single seek-to-end-and-write call. A truncating/whole-file write here would
// destroy real user data (research/PITFALLS.md Pitfall 7), not just Islet's own state.
enum QuickNotesVaultWriter {
    struct WriteError: Error { let underlying: Error }

    static func append(note text: String, to fileURL: URL, at date: Date) throws {
        let fm = FileManager.default
        if !fm.fileExists(atPath: fileURL.path) {
            fm.createFile(atPath: fileURL.path, contents: nil)
        }
        let handle = try FileHandle(forWritingTo: fileURL)
        defer { try? handle.close() }

        let tailInfo = try readTail(of: fileURL, windowBytes: 4096)
        let today = QuickNotesFormatter.isoDate(date)
        var payload = ""

        if tailInfo.sizeBytes > 0 && !tailInfo.endsWithNewline {
            payload += "\n"
        }
        if tailInfo.lastHeadingDate != today {
            if tailInfo.sizeBytes > 0 { payload += "\n" }
            payload += "## \(today)\n\n"
        }
        payload += QuickNotesFormatter.formatEntry(text: text, at: date)

        handle.seekToEndOfFile()
        handle.write(Data(payload.utf8))
    }

    static func isValidVaultFolder(atPath path: String) -> Bool {
        var isDirectory: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory)
        return exists && isDirectory.boolValue
    }

    private static func readTail(of fileURL: URL, windowBytes: Int) throws
        -> (sizeBytes: UInt64, endsWithNewline: Bool, lastHeadingDate: String?) {
        let handle = try FileHandle(forReadingFrom: fileURL)
        defer { try? handle.close() }
        let size = try handle.seekToEnd()
        guard size > 0 else { return (0, true, nil) }

        let offset = size > UInt64(windowBytes) ? size - UInt64(windowBytes) : 0
        try handle.seek(toOffset: offset)
        let tailData = handle.readDataToEndOfFile()
        let tailString = String(decoding: tailData, as: UTF8.self)

        let endsWithNewline = tailData.last == 0x0A
        let lines = tailString.split(separator: "\n", omittingEmptySubsequences: false)
        let lastHeadingLine = lines.last { $0.hasPrefix("## ") }
        let lastHeadingDate = lastHeadingLine.map { String($0.dropFirst(3)) }

        return (size, endsWithNewline, lastHeadingDate)
    }
}
