import Foundation

public class TaskChain {
    public class Chain {
        private var didComplete = false
        fileprivate var didSucceed: (Any?)->Void = { _ in }
        fileprivate var didThrow: (Error)->Void = { _ in }

        init() {
        }

        public func succcess(_ param: Any?=nil) {
            guard !didComplete else {
                assertionFailure("Cannot perform succcess() when chain already completed.")
                return
            }
            didComplete = true
            didSucceed(param)
        }
        public func `throw`(_ error: Error) {
            guard !didComplete else {
                assertionFailure("Cannot perform throw() when chain already completed.")
                return
            }
            didComplete = true
            didThrow(error)
        }
    }

    public typealias NextCompletionError = (Error)->Void

    struct TaskInfo {
        let block: (Chain)->Void
        let paramType: Any.Type
    }

    private var didStart = false
    private var tasks: [TaskInfo] = []
    private var nextParam: Any?
    private var catchHandler: (Error)->Void = { _ in }

    public init() {
        nextParam = nil
    }

    public func `try`(_ completion: @escaping (Chain)->Void ) {
        let taskInfo = TaskInfo(block: completion, paramType: Void.self)
        self.tasks.append( taskInfo )
    }

    public func `try`<RequiredType>(_ completion: @escaping (_ param: RequiredType, Chain)->Void ) {
        let taskInfo = TaskInfo(block: { chain in
            guard let nextParam = self.nextParam as? RequiredType else {
                print("ERROR: nextParam is nil!")
                return
            }
            completion(nextParam, chain)
        }, paramType: RequiredType.self)
        self.tasks.append( taskInfo )
    }

    public func `catch`(_ completion: @escaping NextCompletionError) {
        self.catchHandler = completion
    }

    public func start() {
        guard !self.didStart else {
            print("ERROR: Already started!")
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
                print("nextParam does not match paramType!")
                return
            }
        } else {
            guard (nextParam == nil && task.paramType == Void.self) else {
                print("not expecting paramater!")
                return
            }
        }

        let chain = Chain()
        print("found a block: \(task.block)")
        chain.didSucceed = { param in
            self.nextParam = param
            self.runBlock()
        }
        chain.didThrow = { error in
            print("did throw: \(error.localizedDescription)")
        }
        task.block(chain)
    }
}
