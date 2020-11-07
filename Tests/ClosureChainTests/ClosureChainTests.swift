import XCTest
@testable import ClosureChain

final class ClosureChainTests: XCTestCase {
    /// A typical async method that can possibly succeed or fail
    /// - Parameter completion: completion handler executed on success
    func someAsyncThing(delay: TimeInterval, result: Result<Int,Error>, _ completion: @escaping (Result<Int,Error>)->Void) {
        DispatchQueue.main.asyncAfter(deadline: .now()+delay) {
            completion(result)
        }
    }
    func testExample() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct
        // results.

        let tc = ClosureChain()

        tc.try { (chain: ClosureChain.Chain) in
            print("Returning '4'")
            chain.succcess(4)
        }
        tc.try { (x: Int, chain: ClosureChain.Chain) in
            print("Returning 'Foo'")
            chain.succcess("Foo")
        }

        tc.catch { (error) in
            print("Error handler: \(error)")
        }

        tc.start()

        tc.wait()
    }

    static var allTests = [
        ("testExample", testExample),
    ]
}
