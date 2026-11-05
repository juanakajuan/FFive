import Foundation
import SQLite3

/// Why `store-expect <model> <field> <value>` does not hold yet, or nil once some row matches.
/// A missing or busy store is a reason to keep polling. Any other failure throws.
func storeMismatch(path: String, model: String, field: String, value: String) throws -> String? {
    guard FileManager.default.fileExists(atPath: path) else { return "no on-disk store at \(path) yet" }
    let table = "Z" + model.uppercased()
    let column = "Z" + field.uppercased()
    let condition =
        switch value {
        case "null": "is null"
        case "not-null": "is not null"
        default: "= ?"
        }
    do {
        let store = try Store(path: path)
        defer { store.close() }
        let tables = try store.firstColumn(
            "select name from sqlite_master where type = 'table' and name like 'Z%' and name not like 'Z\\_%' escape '\\' order by name"
        )
        guard tables.contains(table) else {
            throw StoreError.failed("no table \(table); tables: \(tables.joined(separator: ", "))")
        }
        let columns = try store.firstColumn("select name from pragma_table_info('\(table)')")
        guard columns.contains(column) else {
            throw StoreError.failed("no column \(column) in \(table); columns: \(columns.joined(separator: ", "))")
        }
        // Bound as text, the value takes the column's affinity: a number column compares 25 with 25.0, a text column compares strings.
        if try store.firstColumn(
            "select count(*) from \(table) where \(column) \(condition)", binding: condition == "= ?" ? value : nil)
            != ["0"]
        {
            return nil
        }
        let values = try store.firstColumn("select distinct \(column) from \(table) limit 10")
        return
            "no \(model) row has \(field) \(condition.replacingOccurrences(of: "?", with: value)); values: \(values.joined(separator: ", "))"
    } catch StoreError.busy(let reason) {
        return reason
    }
}

enum StoreError: Error, CustomStringConvertible {
    case busy(String)
    case failed(String)

    var description: String {
        switch self {
        case .busy(let reason), .failed(let reason): reason
        }
    }
}

struct Store {
    private let db: OpaquePointer

    init(path: String) throws {
        var handle: OpaquePointer?
        let rc = sqlite3_open_v2(path, &handle, SQLITE_OPEN_READONLY, nil)
        guard rc == SQLITE_OK, let handle else {
            defer { sqlite3_close(handle) }
            throw Self.error(rc, handle, "opening \(path)")
        }
        db = handle
    }

    func close() { sqlite3_close(db) }

    func firstColumn(_ sql: String, binding text: String? = nil) throws -> [String] {
        var statement: OpaquePointer?
        let prepared = sqlite3_prepare_v2(db, sql, -1, &statement, nil)
        guard prepared == SQLITE_OK else { throw Self.error(prepared, db, sql) }
        defer { sqlite3_finalize(statement) }
        if let text { sqlite3_bind_text(statement, 1, text, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self)) }
        var rows: [String] = []
        var rc = sqlite3_step(statement)
        while rc == SQLITE_ROW {
            rows.append(sqlite3_column_text(statement, 0).map { String(cString: $0) } ?? "null")
            rc = sqlite3_step(statement)
        }
        guard rc == SQLITE_DONE else { throw Self.error(rc, db, sql) }
        return rows
    }

    private static func error(_ rc: Int32, _ db: OpaquePointer?, _ context: String) -> StoreError {
        let message = db.map { String(cString: sqlite3_errmsg($0)) } ?? String(cString: sqlite3_errstr(rc))
        return switch rc & 0xff {
        case SQLITE_BUSY: .busy("store is locked (SQLITE_BUSY: \(message)) in `\(context)`")
        case SQLITE_LOCKED: .busy("store is locked (SQLITE_LOCKED: \(message)) in `\(context)`")
        default: .failed("SQLite error \(rc) (\(message)) in `\(context)`")
        }
    }
}
