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

    enum VaultDeleteResult: Equatable { case removed, notFound }

    /// Phase 64-07 (gap closure) — the ONE deliberate, scoped exception to this file's D-07
    /// append-only rule: it only runs on an explicit, rare, single-row user delete, never on
    /// the hot append path above. Unlike `append`, this reads and rewrites the whole file, but
    /// never via a truncating in-place write — the rewritten content is written to a hidden
    /// temp file in the SAME directory as the target, then atomically swapped into place via
    /// `FileManager.replaceItemAt`, giving the same "safe save while another process (Obsidian)
    /// may have the file open" guarantee ordinary text editors rely on.
    ///
    /// `occurrence` (0-based) disambiguates the case where two or more notes format to the
    /// byte-identical entry block (same text, same to-the-minute timestamp) — `range(of:)`
    /// alone always finds the first match regardless of which physical line the caller
    /// actually means. Plan 64-08 computes the correct `occurrence` value from its own ordered
    /// note list before calling this function.
    static func removeEntry(matching note: QuickNote, occurrence: Int = 0, from fileURL: URL) throws -> VaultDeleteResult {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return .notFound }

        let data = try Data(contentsOf: fileURL)
        guard let content = String(data: data, encoding: .utf8) else {
            throw DecodeError()
        }

        let entryBlock = QuickNotesFormatter.formatEntry(text: note.text, at: note.timestamp)

        var searchStart = content.startIndex
        var matchCount = 0
        var targetRange: Range<String.Index>?
        while let range = content.range(of: entryBlock, range: searchStart..<content.endIndex) {
            if matchCount == occurrence {
                targetRange = range
                break
            }
            matchCount += 1
            searchStart = range.upperBound
        }

        guard let foundRange = targetRange else { return .notFound }

        var updated = content
        updated.removeSubrange(foundRange)

        let tempURL = fileURL.deletingLastPathComponent()
            .appendingPathComponent(".\(fileURL.lastPathComponent).tmp-\(UUID().uuidString)")
        try updated.write(to: tempURL, atomically: true, encoding: .utf8)
        _ = try FileManager.default.replaceItemAt(fileURL, withItemAt: tempURL)

        return .removed
    }

    struct DecodeError: Error {}

    static func listMarkdownFiles(inFolder path: String) -> [String] {
        let entries = (try? FileManager.default.contentsOfDirectory(atPath: path)) ?? []
        return entries.filter { $0.hasSuffix(".md") }.sorted()
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
