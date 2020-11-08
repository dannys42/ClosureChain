import Foundation

/// ClosureChain simplifies sequential async completion methods for Swift. It provides a familiar try-catch pattern
/// for sequential async methods.
public class ClosureChain {
    /// Failures that may be sent to the `catch` block due to run-time errors
    public enum Failures: LocalizedError {
        /// Cannot execute `Link.succeed()` more than once per try block
        case cannotSucceedTwicePerTry

        /// Cannot `throw` or `Link.throw()` more than once per chain
        case cannotThrowTwice

        /// Try block specifies a parameter requirement, but none was given by the previous try block
        case tryBlockExpectsPriorSuccessWithParameter

        /// Cannot .start() a chain more than once
        case cannotStartTwice

        /// A chain with a try block was declared but never started
        case chainWasNeverStarted

        /// Try block specifies a parameter requirement, but the type does not match given by the previous try block.  (expected, actual)
        case parameterTypeMismatch(Any.Type,Any.Type)

        case noParameterAvailable

        public var errorDescription: String? {
            switch self {
            case .cannotSucceedTwicePerTry: return "Cannot execute .succeed() more than once per try block"
            case .cannotThrowTwice: return "Cannot throw more than once per chain"
            case .tryBlockExpectsPriorSuccessWithParameter: return "Try block specifies a parameter requirement, but none was given by the previous try block"
            case .cannotStartTwice: return "Cannot .start() a chain more than once"
            case .chainWasNeverStarted: return "A chain with a try block was declared but never started"
            case .parameterTypeMismatch(let expected, let actual): return "Try block specifies a parameter requirement, but the type does not match given by the previous try block  (expected: \(expected)  actual: \(actual))"
            case .noParameterAvailable: return ".noParameterAvailable"
            }
        }
    }

    /// Every `ClosureChain` has a single `CatchHandler` associated with it.  If any errors are thrown within a try-block, or from `ClosureChain` itself due to usage errors, subsequent try-blocks will no longer be called and the `CatchHandler` will receive the associated `Error`.
    public typealias CatchHandler = (Error)->Void

    private struct LinkInfo {
        let block: (Link)->Void
        let paramType: Any.Type
    }

    private var didStart = false
    private var numLinks = 0
    private var links: [LinkInfo] = []
    private var nextParam: Any?
    private var catchHandler: CatchHandler

    /// Initialize a closure chain
    public init() {
        self.nextParam = nil
        self.catchHandler = { _ in }
        self.catchHandler = { _ in
            self.reset()
        }
    }

    /// Execute a block.
    /// Each `try` block will be executed sequentially with another.
    /// - Parameter completion: Block to execute.  This block *must* call either `Link.success()` or `throw` an error to continue the `ClosureChain`
    public func `try`(_ completion:  @escaping (Link) throws -> Void ) {
        self.numLinks += 1
        let linkInfo = LinkInfo(block: { chain in
            do {
                try completion(chain)
            } catch {
                self.catchHandler(error)
            }
        }, paramType: Void.self)
        self.links.append( linkInfo )
    }

    /// Execute a block.
    /// Each `try` block will be executed sequentially with another.
    /// - Parameter completion: Block to execute.  A parameter can be specified with type.  This type must match exactly the type of the `.success()` call of a prior `try` block.  This block *must* call either `Link.success()` or `throw` an error to continue the `ClosureChain`
    public func `try`<RequiredType>(_ completion: @escaping (_ param: RequiredType, Link) throws ->Void ) {
        self.numLinks += 1
        let linkInfo = LinkInfo(block: { chain in
            guard let nextParam = self.nextParam as? RequiredType else {
                self.catchHandler(Failures.tryBlockExpectsPriorSuccessWithParameter)
                return
            }
            do {
                try completion(nextParam, chain)
            } catch {
                self.catchHandler(error)
            }
        }, paramType: RequiredType.self)
        self.links.append( linkInfo )
    }

    /// Error handler.
    /// This error handler is called if any try-block has thrown an error (or if `ClosureChain` throws an error).  No subsequent try-blocks will be executed.
    /// - Parameter completion: Error handler
    public func `catch`(_ completion: @escaping CatchHandler) {
        self.catchHandler = { error in
            completion(error)
            self.reset()
        }
    }

    /// This method must be called at some point after all try-blocks have been defined.  No try-blocks will be executed otherwise.
    public func start() {
        guard !self.didStart else {
            self.catchHandler(Failures.cannotStartTwice)
            return
        }
        self.didStart = true
        self.runLink()
    }

    deinit {
//        #if DEBUG
//        if !self.didStart && self.numClosures > 0 {
//            print("warning: ClosureChain was not started before deinit")
//            self.catchHandler(Failures.chainWasNeverStarted)
//        }
//        #endif
    }

    private func reset() {
        self.links = []
        self.nextParam = nil
    }

    private func popElements() -> LinkInfo? {
        guard self.links.count > 0 else {
            return nil
        }
        let linkInfo = self.links.removeFirst()
        return linkInfo
    }

    private func runLink() {
        defer { self.nextParam = nil }
        guard let link = self.popElements() else {
            return
        }
        if let nextParam = self.nextParam {
            let expectedType = link.paramType
            let actualType = type(of: nextParam)
            guard expectedType == actualType else {
                self.catchHandler(Failures.parameterTypeMismatch(expectedType, actualType) )
                return
            }
        } else {
            guard link.paramType == Void.self else {
                self.catchHandler(Failures.noParameterAvailable)
                return
            }
        }

        let chain = Link()
        chain.didSucceed = { param in
            self.nextParam = param
            self.runLink()
        }
        chain.didThrow = { error in
            self.catchHandler(error)
        }
        link.block(chain)
    }
}

public extension ClosureChain {
    /// `ClosureChain` sequentially executes try-blocks, also known as `Link`s.  Links must receive exactly one of either a `.success()` or a `.throw()` to signfiy the completion of the `Link.`

    class Link {
        private var didComplete = false
        fileprivate var didSucceed: (Any?)->Void = { _ in }
        fileprivate var didThrow: (Error)->Void = { _ in }

        init() {
        }

        /// Signify a successful completion of a `Link`.
        /// - Parameter param: An optional parameter may be specified, to be passed to the next `Link` (try-block)
        public func succcess(_ param: Any?=nil) {
            guard !didComplete else {
                self.didThrow(Failures.cannotSucceedTwicePerTry)
                return
            }
            didComplete = true
            didSucceed(param)
        }

        /// Any `Link` may throw by calling `.throw(Error)` or `throw Error`
        public func `throw`(_ error: Error) {
            guard !didComplete else {
                self.didThrow(Failures.cannotThrowTwice)
                return
            }
            didComplete = true
            didThrow(error)
        }
    }
}

extension ClosureChain.Failures: Equatable {
    /// Determine if two ClosureChain.Failures are equal
    /// - Parameters:
    ///   - lhs: ClosureChain.Failures
    ///   - rhs: ClosureChain.Failures
    /// - Returns: if lhs and rhs and all parameters are equal
    public static func == (lhs: ClosureChain.Failures, rhs: ClosureChain.Failures) -> Bool {
        switch lhs {
        case cannotSucceedTwicePerTry: return rhs == .cannotSucceedTwicePerTry
        case cannotThrowTwice: return rhs == .cannotThrowTwice
        case tryBlockExpectsPriorSuccessWithParameter: return rhs == .tryBlockExpectsPriorSuccessWithParameter
        case cannotStartTwice: return rhs == .cannotStartTwice
        case chainWasNeverStarted: return rhs == .chainWasNeverStarted
        case parameterTypeMismatch(let lhsExpected, let lhsActual):
            switch rhs {
            case .parameterTypeMismatch(let rhsExpected, let rhsActual):
                return lhsExpected == rhsExpected && lhsActual == rhsActual
            default:
                return false
            }
        case noParameterAvailable: return rhs == .noParameterAvailable

        }
    }
}
