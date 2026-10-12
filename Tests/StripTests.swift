// Dependency-free tests for the layout model. Run with scripts/test.sh.
import Foundation

private var failures = 0
private var current = ""

private func check(_ ok: Bool, _ what: String, line: Int = #line) {
    if !ok { failures += 1; print("  FAIL [\(current)] line \(line): \(what)") }
}

private func test(_ name: String, _ body: () -> Void) {
    current = name
    let before = failures
    body()
    print(failures == before ? "  ok   \(name)" : "  FAIL \(name)")
}

private let viewport = CGRect(x: 0, y: 25, width: 1000, height: 800)

@main struct StripTests {
    static func main() {
        test("insert goes right of focus and takes focus") {
            var s = Strip<String>()
            s.append("a"); s.append("b"); s.append("c")
            s.focus("a")
            s.insert("new")
            check(s.ids == ["a", "new", "b", "c"], "order \(s.ids)")
            check(s.focusedID == "new", "focus")
        }
        test("removing focused focuses right neighbour") {
            var s = Strip<String>()
            s.append("a"); s.append("b"); s.append("c")
            s.focus("b")
            s.remove("b"); check(s.focusedID == "c", "after b")
            s.remove("c"); check(s.focusedID == "a", "after c")
            s.remove("a"); check(s.focusedID == nil, "empty")
        }
        test("removing left of focus keeps same window focused") {
            var s = Strip<String>()
            s.append("a"); s.append("b"); s.append("c")
            s.focus("c")
            s.remove("a")
            check(s.focusedID == "c", "focus")
        }
        test("two halves fill usable width exactly") {
            var s = Strip<String>(gap: 10)
            s.append("a", width: 0.5); s.append("b", width: 0.5)
            let f = s.frames(in: viewport)
            check(f[0].frame.minX == 10, "left edge")
            check(f[1].frame.maxX == 990, "right edge")
            check(f[1].frame.minX - f[0].frame.maxX == 10, "gap")
            check(f.allSatisfy { $0.isOnScreen }, "visible")
        }
        test("focusing offscreen column scrolls just enough") {
            var s = Strip<String>(gap: 10)
            for id in ["a", "b", "c"] { s.append(id, width: 0.5) }
            s.focus("c")
            s.revealFocused(viewportWidth: viewport.width)
            let f = s.frames(in: viewport)
            check(f[2].frame.maxX == 990, "c right edge \(f[2].frame)")
            check(f[1].frame.minX == 10, "b left edge \(f[1].frame)")
            check(!f[0].isOnScreen, "a hidden")
        }
        test("move swaps and focus follows") {
            var s = Strip<String>()
            s.append("a"); s.append("b"); s.append("c")
            s.focus("a")
            s.moveFocused(1)
            check(s.ids == ["b", "a", "c"], "order \(s.ids)")
            check(s.focusedID == "a", "focus")
            s.moveFocused(-5)
            check(s.ids == ["a", "b", "c"], "clamped \(s.ids)")
        }
        test("width cycles and full width restores") {
            var s = Strip<String>()
            s.append("a", width: 1.0 / 3)
            s.cycleWidth(); check(s.columns[0].width == 0.5, "half")
            s.toggleFullWidth(); check(s.columns[0].width == 1, "full")
            s.toggleFullWidth(); check(s.columns[0].width == 0.5, "restored")
            s.cycleWidth(); s.cycleWidth(); check(s.columns[0].width == 1.0 / 3, "wraps")
        }
        test("nearest preset snaps pixel width") {
            let s = Strip<String>(gap: 10)
            check(s.nearestPreset(forPixelWidth: 480, viewportWidth: 1000) == 0.5, "half")
            check(s.nearestPreset(forPixelWidth: 970, viewportWidth: 1000) == 1, "full")
        }
        print(failures == 0 ? "All tests passed." : "\(failures) check(s) failed.")
        if failures > 0 { exit(1) }
    }
}
