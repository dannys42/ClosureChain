import XCTest
@testable import ClosureChain

final class ClosureChainTests: XCTestCase {
    enum Failures: Error {
        case someFailure
    }
    /// A typical async method that can possibly succeed or fail
    /// - Parameter completion: completion handler executed on success
    func someAsyncThing(delay: TimeInterval, result: Result<Int,Error>, _ completion: @escaping (Result<Int,Error>)->Void) {
        DispatchQueue.main.asyncAfter(deadline: .now()+delay) {
            completion(result)
        }
    }

    /// Stand-in for function with completion handler using Result type that always succeeds
    /// - Parameters:
    ///   - value: Success value to return
    ///   - completion: completion handler to call
    func callSuccess<Value>(value: Value, _ completion: (Result<Value, Error>)->Void) {
        completion(.success(value))
    }

    /// Stand-in for function with completion handler using Result type that always fails
    /// - Parameters:
    ///   - error: Error value to return
    ///   - completion: completion handler to call
    func callFailure(error: Error, _ completion: (Result<Int, Error>)->Void) {
        completion(.failure(error))
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

    func testThat_Chain_CanIgnoreParameter() {
        let cc = ClosureChain()
        let inputValues: [Any] = [ 4, "Foo" ]
        let expectedValues: [Any] = [ 4 ]
        var result: [Any] = []
        var foundError: Error? = nil
        let g = DispatchGroup()
        let expectedBlockSequence = [ "a", "b", "c" ]
        var resolvedBlockSequence: [String] = []

        g.enter()
        cc.try { link in
            defer { g.leave() }
            resolvedBlockSequence.append("a")
            link.success(inputValues[0])
        }

        g.enter()
        cc.try { (x: Int, link) in
            defer { g.leave() }
            resolvedBlockSequence.append("b")
            result.append(x)
            link.success(inputValues[1])
        }

        g.enter()
        cc.try { link in
            defer { g.leave() }
            resolvedBlockSequence.append("c")
            link.success()
        }

        cc.catch { (error) in
            foundError = error
        }

        cc.start()

        _ = g.wait(timeout: .now()+5)

        XCTAssertEqual(expectedBlockSequence, resolvedBlockSequence, "Expected blocks: \(expectedBlockSequence)  Resolved blocks: \(resolvedBlockSequence)")
        XCTAssertNil(foundError, "No error expected")
        XCTAssertEqual(expectedValues.count, result.count, "Expected same number of expected and push values")
        XCTAssertEqual(expectedValues[0] as? Int, inputValues[0] as? Int, "Expected result[0] == 4")
    }

    func testThat_PassingWrongParameter_Fails() {
        let cc = ClosureChain()
        let inputValues: [Any] = [ 4, "Foo" ]
        let expectedValues: [Any] = [ 4 ]
        var result: [Any] = []
        var foundError: Error? = nil
        let g = DispatchGroup()
        let expectedBlockSequence = [ "a", "b" ]
        var resolvedBlockSequence: [String] = []

        g.enter()
        cc.try { link in
            defer { g.leave() }
            resolvedBlockSequence.append("a")
            link.success(inputValues[0])
        }

        g.enter()
        cc.try { (x: Int, link) in
            defer { g.leave() }
            resolvedBlockSequence.append("b")
            result.append(x)
            link.success(inputValues[1])
        }

        g.enter()
        // wronge parameter type should fail
        cc.try { (v: Date, link) in
            defer { g.leave() }
            resolvedBlockSequence.append("c")
            link.success()
        }

        cc.catch { (error) in
            foundError = error
        }

        cc.start()

        _ = g.wait(timeout: .now()+5)

        XCTAssertEqual(expectedBlockSequence, resolvedBlockSequence, "Expected blocks: \(expectedBlockSequence)  Resolved blocks: \(resolvedBlockSequence)")
        XCTAssertEqual(foundError as? ClosureChain.Failures, ClosureChain.Failures.parameterTypeMismatch(Date.self, String.self), "Expected parameterTypeMismatch error")
        XCTAssertEqual(expectedValues.count, result.count, "Expected same number of expected and push values")
        XCTAssertEqual(expectedValues[0] as? Int, inputValues[0] as? Int, "Expected result[0] == 4")
    }
    func testThat_Chain_CanPassParameter_OfDifferentTypes() {
        let cc = ClosureChain()
        let inputValues: [Any] = [4, "Foo"]
        let expectedValues = inputValues
        var result: [Any] = []
        var foundError: Error? = nil
        let g = DispatchGroup()

        g.enter()
        cc.try { chain in
            defer { g.leave() }
            chain.success(inputValues[0])
        }

        g.enter()
        cc.try { (x: Int, chain) in
            defer { g.leave() }
            result.append(x)
            chain.success(inputValues[1])
        }

        g.enter()
        cc.try { (str: String, chain) in
            defer { g.leave() }
            result.append(str)
            chain.success()
        }

        cc.catch { (error) in
            foundError = error
        }

        cc.start()

        _ = g.wait(timeout: .now()+5)

        XCTAssertNil(foundError, "Expected no errors.  Found: \(foundError!)")
        XCTAssertEqual(expectedValues.count, result.count, "Expected same number of expected and push values")
        XCTAssertEqual(expectedValues[0] as? Int, inputValues[0] as? Int, "Expected result[0] == 4")
        XCTAssertEqual(expectedValues[1] as? String, inputValues[1] as? String, "Expected result[1] == 'Foo'")
    }

    func testThat_SuccessReturns_ContinueChain() {
        let cc = ClosureChain()
        let inputValues: [Any] = [4, "Foo"]
        let expectedValues = inputValues
        var result: [Any] = []
        var foundError: Error? = nil
        let g = DispatchGroup()

        g.enter()
        cc.try { link in
            defer { g.leave() }
            self.callSuccess(value: inputValues[0]) { (result) in
                link.return(result)
            }
        }

        g.enter()
        cc.try { (x: Int, link) in
            defer { g.leave() }
            result.append(x)
            self.callSuccess(value: inputValues[1]) { (result) in
                link.return(result)
            }
        }

        g.enter()
        cc.try { (str: String, link) in
            defer { g.leave() }
            result.append(str)
            link.success()
        }

        cc.catch { (error) in
            foundError = error
        }

        cc.start()

        _ = g.wait(timeout: .now()+5)

        XCTAssertNil(foundError, "Expected no errors.  Found: \(foundError!)")
        XCTAssertEqual(expectedValues.count, result.count, "Expected same number of expected and push values")
        XCTAssertEqual(expectedValues[0] as? Int, inputValues[0] as? Int, "Expected result[0] == 4")
        XCTAssertEqual(expectedValues[1] as? String, inputValues[1] as? String, "Expected result[1] == 'Foo'")
    }

    func testThat_ErrorReturns_StopChain() {
        let cc = ClosureChain()
        let inputValues: [Any] = [4, "Foo"]
        let expectedValues: [Any] = [4]
        var result: [Any] = []
        var foundError: Error? = nil
        let expectedError = Failures.someFailure
        let g = DispatchGroup()

        g.enter()
        cc.try { link in
            defer { g.leave() }
            self.callSuccess(value: inputValues[0]) { (result) in
                link.return(result)
            }
        }

        g.enter()
        cc.try { (x: Int, link) in
            defer { g.leave() }
            result.append(x)
            self.callFailure(error: Failures.someFailure) { (result) in
                link.return(result)
            }
        }

        g.enter()
        cc.try { (str: String, link) in
            defer { g.leave() }
            result.append(str)
            link.success()
        }

        cc.catch { (error) in
            foundError = error
        }

        cc.start()

        _ = g.wait(timeout: .now()+5)

        XCTAssertEqual(foundError as? Failures, expectedError, "Expected error to be \(expectedError.localizedDescription)  Found instead: \(foundError?.localizedDescription ?? "(n/a)")")
        XCTAssertEqual(expectedValues.count, result.count, "Expected same number of expected and push values")
        XCTAssertEqual(expectedValues[0] as? Int, inputValues[0] as? Int, "Expected result[0] == 4")
    }
/*
    static var allTests = [
        ("testThat_Chain_CanPassParameter_OfDifferentTypes", testThat_Chain_CanPassParameter_OfDifferentTypes),
    ]
 */
}
