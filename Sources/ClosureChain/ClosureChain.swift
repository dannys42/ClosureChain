import Foundation

public class ClosureChain {
    public enum Failures: Error {
        case cannotSucceedTwicePerTry
        case cannotThrowTwice
        case tryBlockExpectsPriorSuccessWithParameter
        case cannotStartTwice
        case chainWasNeverStarted
        case parameterTypeMismatch
        case noParameterAvailable
    }


    public typealias CatchHandler = (Error)->Void

    struct TaskInfo {
        let block: (Chain)->Void
        let paramType: Any.Type
    }

    private var didStart = false
    private var tasks: [TaskInfo] = []
    private var nextParam: Any?
    private var catchHandler: CatchHandler = { _ in }

    public init() {
        nextParam = nil
    }

    public func `try`(_ completion:  @escaping (Chain) throws -> Void ) {
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

    public func wait() {
        while self.tasks.count > 0 {
            print(" waiting... ")
            Thread.sleep(forTimeInterval: 1)
        }
    }

    deinit {
//        #if DEBUG
        if !self.didStart {
            print("warning: TaskChain was not started before deinit")
            self.catchHandler(Failures.chainWasNeverStarted)
        }
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
            guard type(of: nextParam) == task.paramType else {
                self.catchHandler(Failures.parameterTypeMismatch)
                return
            }
        } else {
            guard (nextParam == nil && task.paramType == Void.self) else {
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
