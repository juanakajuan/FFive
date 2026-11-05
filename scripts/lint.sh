#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
export LC_ALL=C
baseline=scripts/lint-baseline.txt
rules="view-writes no-stored-builder presentation-at-screen-root no-appstorage-in-app no-userdefaults-in-app no-processinfo-in-app exercise-identity-by-name"
never_baselined="view-writes no-appstorage-in-app no-userdefaults-in-app no-processinfo-in-app exercise-identity-by-name"

scan() {
    for file in "$@"; do
        awk -F'\t' -v path="$file" '
        function code(s) {
            gsub(/"([^"\\]|\\.)*"/, "\"\"", s)
            sub(/\/\/.*/, "", s)
            return s
        }
        function hit(rule, i, fix,    text) {
            text = line[i]
            gsub(/\t/, " ", text)
            gsub(/^ +| +$/, "", text)
            printf "%s\t%s\t%d\t%s\t%s\n", rule, path, i, text, fix
        }
        { line[NR] = $0; src[NR] = code($0) }
        END {
            for (i = 1; i <= NR; i++)
                if (src[i] ~ /(^|[^A-Za-z0-9_])struct[ \t][^{]*:[^{]*(^|[^A-Za-z0-9_])View([^A-Za-z0-9_]|$)/) isView = 1
            for (i = 1; i <= NR; i++) {
                s = src[i]
                if (match(s, /(^|[^A-Za-z0-9_])struct[ \t]+[A-Za-z_][A-Za-z0-9_]*/)) {
                    pending = substr(s, RSTART, RLENGTH)
                    sub(/.*struct[ \t]+/, "", pending)
                }
                if (isView && (s ~ /[cC]ontext\.(delete|insert|save)\(/ || s ~ /\.(finishedDate|endDate)[ \t]*[-+]?=[^=]/))
                    hit("view-writes", i, "A view must not write model state. Move the write into a method on the model or its Store and call that from the view.")
                if (s ~ /@ViewBuilder[ \t]+((private|fileprivate|public|internal)[ \t]+)?(let|var)[ \t]+[A-Za-z0-9_]+[ \t]*:[ \t]*\(\)[ \t]*->/)
                    hit("no-stored-builder", i, "A stored builder closure froze pushed screens (1eeaf4d). Store the built view instead: `let content: Content`, set in `init(@ViewBuilder content: () -> Content)`.")
                if (sp > 0 && s ~ /\.(alert|sheet|confirmationDialog|fullScreenCover)\(/ && name[sp] !~ /(View|Screen)$/)
                    hit("presentation-at-screen-root", i, "Present alerts, sheets, dialogs and covers from the screen struct (a name ending in View or Screen), not from a row or card in a lazy list (2bca9bb). Pass the row a closure that sets the screen state.")
                if (s ~ /@AppStorage/)
                    hit("no-appstorage-in-app", i, "Settings owns every preference. Read `store.settings.<name>` and assign to it instead of an @AppStorage key.")
                if (s ~ /UserDefaults/ && path !~ /FFiveCore\/Sources\/FFiveCore\/Store\/Settings\.swift$/)
                    hit("no-userdefaults-in-app", i, "Only Settings.swift reads or writes UserDefaults. Add the preference to Settings and read it from there.")
                if (s ~ /ProcessInfo/ && path !~ /FFiveCore\/Sources\/FFiveCore\/Store\/LaunchMode\.swift$/)
                    hit("no-processinfo-in-app", i, "Only LaunchMode.swift reads the launch arguments. FFiveApp parses LaunchMode once; take what you need from it.")
                if (path !~ /Catalog\/ExerciseID\.swift$/ && (s ~ /(FetchDescriptor|Predicate)<Exercise>.*\.name[ \t]*==/ || s ~ /[eE]xercise\.name[ \t]*[=!]=/ || s ~ /[=!]=[ \t]*[A-Za-z_.$0-9]*[eE]xercise\.name/ || s ~ /\[[A-Za-z_.$0-9]*[eE]xercise\.name[ \t]*[,\]]/ || s ~ /info\(named:/))
                    hit("exercise-identity-by-name", i, "Exercise identity is ExerciseID, not the name string. Compare or key by exercise.key (or ExerciseID(folding: name) at an input boundary), fetch by exerciseKey, and look the catalog up with ExerciseCatalog.info(_:).")
                for (c = 1; c <= length(s); c++) {
                    ch = substr(s, c, 1)
                    if (ch == "{") {
                        depth++
                        if (pending != "") { sp++; name[sp] = pending; at[sp] = depth; pending = "" }
                    } else if (ch == "}") {
                        if (sp > 0 && at[sp] == depth) sp--
                        depth--
                    }
                }
            }
        }' "$file"
    done
}

# A baseline line is `<rule> <path>: <source line, trimmed>`. It has no line number, so edits
# elsewhere in a file leave it alone. Repeated identical lines each need their own baseline line.
key() { awk -F'\t' '{ print $1 " " $2 ": " $4 }'; }

app_hits() { scan $(find FFive FFiveCore/Sources -name '*.swift' | sort); }

ratchet() {
    awk -F'\t' -v base="$baseline" -v never="$never_baselined" '
    BEGIN { n = split(never, list, " "); for (i = 1; i <= n; i++) neverBaselined[list[i]] = 1 }
    FILENAME == base {
        if ($0 ~ /^#/ || $0 == "") next
        split($0, w, " ")
        if (neverBaselined[w[1]]) { print "rule " w[1] " is never baselined. Fix the hit and delete this line from " base ":\n  " $0; stale++; next }
        left[$0]++
        next
    }
    {
        k = $1 " " $2 ": " $4
        if (!neverBaselined[$1] && left[k] > 0) { left[k]--; kept++; next }
        printf "%s:%d: [%s] %s\n  fix: %s\n", $2, $3, $1, $4, $5
        fresh++
    }
    END {
        for (k in left)
            for (n = 0; n < left[k]; n++) { print "stale baseline line, its hit is gone. Delete it from " base ":\n  " k; stale++ }
        if (fresh + stale > 0) { printf "lint: FAIL %d new, %d stale\n", fresh, stale; exit 1 }
        printf "lint: ok, %d baselined hits, 0 new\n", kept
    }' "$baseline" -
}

self_test() {
    status=0
    for rule in $rules; do
        set -- scripts/lint-fixtures/"$rule"/*.swift
        [ -e "$1" ] || { echo "self-test: rule $rule has no fixture in scripts/lint-fixtures/$rule/"; status=1; continue; }
        for fixture in "$@"; do
            found=$(scan "$fixture" | awk -F'\t' -v rule="$rule" '$1 == rule' | wc -l | tr -d ' ')
            [ "$found" -gt 0 ] || { echo "self-test: rule $rule found nothing in $fixture"; status=1; }
            echo "self-test: $rule hits $found in $fixture"
        done
    done
    [ "$status" -eq 0 ] || exit 1
    echo "lint self-test: ok, every rule hits its fixtures"
}

case "${1:-}" in
    --self-test) self_test ;;
    --hits) app_hits | key | sort ;;
    "") app_hits | ratchet ;;
    *) echo "usage: lint.sh [--self-test | --hits]" >&2; exit 2 ;;
esac
