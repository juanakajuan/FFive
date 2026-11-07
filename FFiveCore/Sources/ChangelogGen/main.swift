import FFiveCore
import Foundation

// Reads releases and commits from stdin and prints Changelog.json. scripts/changelog.sh feeds it:
//   R<TAB>version<TAB>yyyy-MM-dd      starts a release, newest first
//   C<TAB>yyyy-MM-dd<TAB>subject      a commit in the release above
// Only conventional feat, fix and perf commits reach the lifter; tooling scopes stay out.

let input = String(decoding: FileHandle.standardInput.readDataToEndOfFile(), as: UTF8.self)
let changelog = ChangelogInput.parse(input)
let encoder = JSONEncoder()
encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
FileHandle.standardOutput.write(try encoder.encode(changelog))
FileHandle.standardOutput.write(Data("\n".utf8))
