import XCTest
@testable import TaskChain

final class TaskChainTests: XCTestCase {
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

        let tc = TaskChain()

        tc.try { (chain: TaskChain.Chain) in
            print("Returning '4'")
            chain.succcess(4)
        }
        tc.try { (x: Int, chain: TaskChain.Chain) in
            print("Returning 'Foo'")
            chain.succcess("Foo")
        }

//        tc.next { (done : @escaping TaskChain.NextHandler<Int>) in
//            self.someAsyncThing(delay: 0.1, result: .success(2)) { (result) in
//                done(.success(3))
//            }
//        }
//
//        tc.next { (param: Int, done : @escaping TaskChain.NextHandler<String>) in
//            self.someAsyncThing(delay: 0.1, result: .success(2)) { (result) in
//                done(.success("good"))
//            }
//        }
//
//        tc.next { done in
//            done()
//        }

        tc.catch { (error) in
            print("Error handler: \(error)")
        }

        tc.start()

        tc.wait()
    }

//
//        tc.next() { (b: Bool, completion) in
//            completion(.success(true))
//        }

//        XCTAssertEqual(TaskChain().text, "Hello, World!")

    static var allTests = [
        ("testExample", testExample),
    ]
}
