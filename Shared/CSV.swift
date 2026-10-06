import Foundation

enum ParseError: Error, Equatable {
    case notUTF8
    case missingColumn(String)
    case noRows
}

enum CSV {
    /// RFC 4180: quoted fields, doubled quotes, commas and newlines inside quotes, LF or CRLF.
    static func parse(_ text: String) -> [[String]] {
        var rows: [[String]] = []
        var row: [String] = []
        var field = String.UnicodeScalarView()
        var inQuotes = false
        let scalars = Array(text.unicodeScalars)
        var i = 0
        while i < scalars.count {
            let c = scalars[i]
            if inQuotes {
                if c == "\"" {
                    if i + 1 < scalars.count, scalars[i + 1] == "\"" {
                        field.append("\"")
                        i += 1
                    } else {
                        inQuotes = false
                    }
                } else {
                    field.append(c)
                }
            } else {
                switch c {
                case "\"": inQuotes = true
                case ",":
                    row.append(String(field))
                    field = String.UnicodeScalarView()
                case "\n":
                    row.append(String(field))
                    rows.append(row)
                    row = []
                    field = String.UnicodeScalarView()
                case "\r": break
                default: field.append(c)
                }
            }
            i += 1
        }
        if !field.isEmpty || !row.isEmpty {
            row.append(String(field))
            rows.append(row)
        }
        return rows
    }

    /// Maps header names to column indexes.
    static func columns(_ header: [String]) -> [String: Int] {
        Dictionary(header.enumerated().map { ($1, $0) }, uniquingKeysWith: { first, _ in first })
    }
}
