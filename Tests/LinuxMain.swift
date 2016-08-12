#if os(Linux)

import XCTest
@testable import MustacheTests

XCTMain([
    testCase(MustacheTests.allTests)
])

#endif
