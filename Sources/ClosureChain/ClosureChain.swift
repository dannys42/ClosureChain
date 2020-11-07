import Foundation

public class ClosureChain {
    public enum Failures: LocalizedError {
        case cannotSucceedTwicePerTry
        case cannotThrowTwice
        case tryBlockExpectsPriorSuccessWithParameter
        case cannotStartTwice
        case chainWasNeverStarted
        case parameterTypeMismatch(Any.Type,Any.Type)
        case noParameterAvailable

        public var errorDescription: String? {
            switch self {
            case .cannotSucceedTwicePerTry: return "Cannot execute .succeed() more than once per try block"
            case .cannotThrowTwice: return "Cannot more than once per chain"
            case .tryBlockExpectsPriorSuccessWithParameter: return "Try block specifies a parameter requirement, but none was given by the previous try block"
            case .cannotStartTwice: return "Cannot .start() a chain more than once"
            case .chainWasNeverStarted: return "A chain with a try block was declared but never started."
            case .parameterTypeMismatch(let expected, let actual): return "Try block specifies a parameter requirement, but the type does not match given by the previous try block  (expected: \(expected)  actual: \(actual))"
            case .noParameterAvailable: return ".noParameterAvailable"
            }
        }
    }

    public typealias CatchHandler = (Error)->Void

    struct TaskInfo {
        let block: (Chain)->Void
        let paramType: Any.Type
    }

    private var didStart = false
    private var numClosures = 0
    private var tasks: [TaskInfo] = []
    private var nextParam: Any?
    private var catchHandler: CatchHandler = { _ in }

    public init() {
        nextParam = nil
    }

    public func `try`(_ completion:  @escaping (Chain) throws -> Void ) {
        self.numClosures += 1
        let taskInfo = TaskInfo(block: { chain in
            do {
                try completion(chain)
            } catch {
                self.catchHandler(error)
            }
        }, paramType: Void.self)
        self.tasks.append( taskInfo )
    }

    public func `try`<RequiredType>(_ completion: @escaping (_ param: RequiredType, Chain) throws ->Void ) {
        self.numClosures += 1
        let taskInfo = TaskInfo(block: { chain in
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
        self.tasks.append( taskInfo )
    }

    public func `catch`(_ completion: @escaping CatchHandler) {
        self.catchHandler = completion
    }

    public func start() {
        guard !self.didStart else {
            self.catchHandler(Failures.cannotStartTwice)
            return
        }
        self.didStart = true
        self.runBlock()
    }

    deinit {
//        #if DEBUG
//        if !self.didStart && self.numClosures > 0 {
//            print("warning: TaskChain was not started before deinit")
//            self.catchHandler(Failures.chainWasNeverStarted)
//        }
//        #endif
    }

    private func popElements() -> TaskInfo? {
        guard self.tasks.count > 0 else {
            return nil
        }
        let taskInfo = self.tasks.removeFirst()
        return taskInfo
    }

    private func runBlock() {
        defer { self.nextParam = nil }
        guard let task = self.popElements() else {
            return
        }
        if let nextParam = self.nextParam {
            let expectedType = task.paramType
            let actualType = type(of: nextParam)
            guard expectedType == actualType else {
                self.catchHandler(Failures.parameterTypeMismatch(expectedType, actualType) )
                return
            }
        } else {
            guard task.paramType == Void.self else {
                self.catchHandler(Failures.noParameterAvailable)
                return
            }
        }

        let chain = Chain()
        chain.didSucceed = { param in
            self.nextParam = param
            self.runBlock()
        }
        chain.didThrow = { error in
            self.catchHandler(error)
        }
        task.block(chain)
    }
}

public extension ClosureChain {
    class Chain {
        private var didComplete = false
        fileprivate var didSucceed: (Any?)->Void = { _ in }
        fileprivate var didThrow: (Error)->Void = { _ in }

        init() {
        }

        public func succcess(_ param: Any?=nil) {
            guard !didComplete else {
                self.didThrow(Failures.cannotSucceedTwicePerTry)
                return
            }
            didComplete = true
            didSucceed(param)
        }
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
