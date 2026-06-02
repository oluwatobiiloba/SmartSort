//
//  NearDuplicateGrouperTests.swift
//  SmartSortTests
//

import Testing
@testable import SmartSort

struct NearDuplicateGrouperTests {

    @Test func groupsItemsWithinThreshold() {
        // Same first letter => similar.
        let groups = NearDuplicateGrouper().groups(["a1", "a2", "b"], threshold: 0.5) {
            $0.first == $1.first ? 0.1 : 1.0
        }
        #expect(groups.count == 1)
        #expect(Set(groups[0]) == ["a1", "a2"])
    }

    @Test func returnsNoGroupsWhenAllDistinct() {
        let groups = NearDuplicateGrouper().groups(["a", "b", "c"], threshold: 0.5) {
            $0 == $1 ? 0.0 : 1.0
        }
        #expect(groups.isEmpty)
    }

    @Test func chainsSimilarItemsTransitively() {
        // a~b and b~c, but a and c are far apart → single linkage still merges all three.
        let close: Set<Set<String>> = [["a", "b"], ["b", "c"]]
        let groups = NearDuplicateGrouper().groups(["a", "b", "c"], threshold: 0.5) {
            close.contains([$0, $1]) ? 0.1 : 1.0
        }
        #expect(groups.count == 1)
        #expect(Set(groups[0]) == ["a", "b", "c"])
    }

    @Test func emptyAndSingletonInputsYieldNoGroups() {
        #expect(NearDuplicateGrouper().groups([String](), threshold: 0.5) { _, _ in 0 }.isEmpty)
        #expect(NearDuplicateGrouper().groups(["solo"], threshold: 0.5) { _, _ in 0 }.isEmpty)
    }
}
