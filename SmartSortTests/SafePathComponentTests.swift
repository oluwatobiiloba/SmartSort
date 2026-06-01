//
//  SafePathComponentTests.swift
//  SmartSortTests
//

import Testing
import Foundation
@testable import SmartSort

struct SafePathComponentTests {

    @Test func keepsOrdinaryNames() {
        #expect(SafePathComponent.make("Invoices", fallback: "X") == "Invoices")
        #expect(SafePathComponent.make("Travel Photos", fallback: "X") == "Travel Photos")
    }

    @Test func stripsPathSeparators() {
        let result = SafePathComponent.make("Foo/Bar", fallback: "X")
        #expect(!result.contains("/"))
        let win = SafePathComponent.make("a\\b:c", fallback: "X")
        #expect(!win.contains("\\"))
        #expect(!win.contains(":"))
    }

    @Test func neutralizesTraversalSequences() {
        // No result may be a traversal token or contain a separator.
        for raw in ["..", ".", "../../etc", "../../../etc/passwd", "/etc/passwd", "....//"] {
            let result = SafePathComponent.make(raw, fallback: "Fallback")
            #expect(result != "..")
            #expect(result != ".")
            #expect(!result.contains("/"))
            #expect(!result.hasPrefix("."))
            #expect(!result.isEmpty)
        }
    }

    @Test func stripsLeadingDotsAndNewlines() {
        #expect(SafePathComponent.make(".hidden", fallback: "X") == "hidden")
        #expect(!SafePathComponent.make("line1\nline2", fallback: "X").contains("\n"))
    }

    @Test func fallsBackWhenEmptyAfterCleaning() {
        #expect(SafePathComponent.make("", fallback: "Fallback") == "Fallback")
        #expect(SafePathComponent.make("   ", fallback: "Fallback") == "Fallback")
        #expect(SafePathComponent.make("///", fallback: "Fallback") == "Fallback")
    }

    @Test func capsLength() {
        let long = String(repeating: "a", count: 500)
        #expect(SafePathComponent.make(long, fallback: "X", maxLength: 100).count <= 100)
    }
}
