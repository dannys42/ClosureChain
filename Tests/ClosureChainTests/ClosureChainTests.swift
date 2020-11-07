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
    func testThat_ChainWithNoTries_HasNoError() throws {
        var foundError: Error? = nil
        repeat {
            let cc = ClosureChain()

            cc.catch { (error) in
                foundError = error
                print("found error: \(error.localizedDescription)")
            }
        } while false

        if let error = foundError {
            XCTFail("Should have no error.  But found: \(error.localizedDescription)")
        }
    }

    /* not possible to check
    func testThat_ChainWithNoStart_HasError() throws {
        var foundError: Error? = nil
        repeat {
            let cc = ClosureChain()

            cc.try { _ in

            }

            cc.catch { (error) in
                foundError = error
                print("found error: \(error.localizedDescription)")
            }
        } while false

        XCTAssertEqual(foundError as? ClosureChain.Failures, ClosureChain.Failures.chainWasNeverStarted,
                       "Should have received a `.chainWasNeverStarted` error")
    }
 */

    func testThat_Chain_CannotIgnoreParameter() {
        let cc = ClosureChain()
        let inputValues: [Any] = [ 4, "Foo" ]
        let expectedValues: [Any] = [ 4 ]
        var result: [Any] = []
        var foundError: Error? = nil
        let g = DispatchGroup()
        let expectedBlockSequence = [ "a", "b" ]
        var resolvedBlockSequence: [String] = []

        g.enter()
        cc.try { chain in
            defer { g.leave() }
            resolvedBlockSequence.append("a")
            chain.succcess(inputValues[0])
        }

        g.enter()
        cc.try { (x: Int, chain) in
            defer { g.leave() }
            resolvedBlockSequence.append("b")
            result.append(x)
            chain.succcess(inputValues[1])
        }

        g.enter()
        cc.try { chain in
            defer { g.leave() }
            resolvedBlockSequence.append("c")
            chain.succcess()
        }

        cc.catch { (error) in
            foundError = error
        }

        cc.start()

        _ = g.wait(timeout: .now()+5)

        XCTAssertEqual(expectedBlockSequence, resolvedBlockSequence, "Expected blocks: \(expectedBlockSequence)  Resolved blocks: \(resolvedBlockSequence)")
        XCTAssertEqual(foundError as? ClosureChain.Failures, ClosureChain.Failures.parameterTypeMismatch(Void.self, String.self), "Expected parameterTypeMismatch error")
        XCTAssertEqual(expectedValues.count, result.count, "Expected same number of expected and push values")
        XCTAssertEqual(expectedValues[0] as? Int, inputValues[0] as? Int, "Expected result[0] == 4")
    }

    func testThat_Chain_CanPassParameter_OfDifferentTypes() {
        let cc = ClosureChain()
        let inputValuse: [Any] = [4, "Foo"]
        let expectedValues = inputValuse
        var result: [Any] = []
        var foundError: Error? = nil
        let g = DispatchGroup()

        g.enter()
        cc.try { chain in
            defer { g.leave() }
            chain.succcess(inputValuse[0])
        }

        g.enter()
        cc.try { (x: Int, chain) in
            defer { g.leave() }
            result.append(x)
            chain.succcess(inputValuse[1])
        }

        g.enter()
        cc.try { (str: String, chain) in
            defer { g.leave() }
            result.append(str)
            chain.succcess()
        }

        cc.catch { (error) in
            foundError = error
        }

        cc.start()

        _ = g.wait(timeout: .now()+5)

        XCTAssertNil(foundError, "Expected no errors.  Found: \(foundError!)")
        XCTAssertEqual(expectedValues.count, result.count, "Expected same number of expected and push values")
        XCTAssertEqual(expectedValues[0] as? Int, inputValuse[0] as? Int, "Expected result[0] == 4")
        XCTAssertEqual(expectedValues[1] as? String, inputValuse[1] as? String, "Expected result[1] == 'Foo'")
    }
/*
    static var allTests = [
        ("testThat_Chain_CanPassParameter_OfDifferentTypes", testThat_Chain_CanPassParameter_OfDifferentTypes),
    ]
 */
}
