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

    public typealias NextHandler<SuccessResult> = (Result<SuccessResult,Error>)->Void
    public typealias NextHandlerBare = ()->Void
    public typealias NextCompletionResult<SuccessResult> = (@escaping NextHandler<SuccessResult>)->Void
    public typealias NextCompletionParamResult<Param,SuccessResult> = (Param, @escaping NextHandler<SuccessResult>)->Void
    public typealias NextCompletionParam<Param> = (Param, @escaping NextHandlerBare)->Void
    public typealias NextCompletion = (@escaping NextHandlerBare)->Void
    public typealias NextCompletionError = (Error)->Void

    struct TaskInfo {
        let block: (Chain)->Void
        let paramType: Any.Type
//
//        init(block: @escaping (Chain)->Void, paramType: Any.Type) {
//            self.block = block
//            self.paramType = paramType
//        }
    }

    private var didStart = false
    private var tasks: [TaskInfo] = []
//    private var blocks: [Any] = []
//    private var paramTypes: [Any.Type] = []
    private var nextParam: Any?
    private var catchHandler: (Error)->Void = { _ in }

//    public func next<SuccessResult>(_ completion: @escaping NextCompletionResult<SuccessResult> ) {
//        print("Appending block: \(completion.self)")
//        let taskInfo = TaskInfo(block: completion, paramType: Void.self)
//        self.tasks.append( taskInfo )
//    }
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

//        let taskInfo = TaskInfo(block: completion, paramType: RequiredType.self)
//        self.tasks.append( taskInfo )
    }

//    public func next<Param,SuccessResult>(_ completion: @escaping NextCompletionParamResult<Param,SuccessResult> ) {
//        print("Appending block: \(completion.self)")
//        let taskInfo = TaskInfo(block: completion, paramType: Param.self)
//        self.tasks.append( taskInfo )
//    }
//
//    public func next<Param>(_ completion: @escaping NextCompletionParam<Param> ) {
//        print("Appending block: \(completion.self)")
//        let taskInfo = TaskInfo(block: completion, paramType: Param.self)
//        self.tasks.append( taskInfo )
//    }
//
//    public func next(_ completion: @escaping NextCompletion ) {
//        print("Appending block: \(completion.self)")
//        let taskInfo = TaskInfo(block: completion, paramType: Void.self)
//        self.tasks.append( taskInfo )
//    }

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

        if let block = task.block as? (TaskChain.Chain)->Void {
            let chain = Chain()
            print("found a block: \(block)")
            chain.didSucceed = { param in
                self.nextParam = param
                self.runBlock()
            }
            chain.didThrow = { error in
                print("did throw: \(error.localizedDescription)")
            }
            block(chain)
//            } else if let block = task.block as? (Any, TaskChain.Chain)->Void {
//                print("found a param block: \(block)")
        } else {
            print("block not found")
        }
    }
/*
        if let blockResult = task.block as? NextCompletion {
            blockResult() {
                self.runBlock()
            }
        } else if let blockParam = task.block as? NextCompletionParam<Any> {
            guard let nextParam = self.nextParam else {
                assertionFailure("Missing next parameter type!")
                return
            }
            guard type(of: nextParam) == task.paramType else {
                assertionFailure("Next parameter type is incorrect!")
                return
            }
            blockParam(nextParam) {
                self.runBlock()
            }
        } else if let blockResult = task.block as? NextCompletionResult<Any> {
            blockResult() { result in
                switch result {
                case .success(let successValue):
                    self.nextParam = successValue
                    self.runBlock()
                case .failure(let error):
                    self.catchHandler(error)
                }
            }
        } else if let blockParamResult = task.block as? NextCompletionParamResult<Any,Any> {
            guard let nextParam = nextParam else {
                assertionFailure("next param required")
                return
            }
            blockParamResult(nextParam) { result in
                switch result {
                case .success(let successValue):
                    self.nextParam = successValue
                    self.runBlock()
                case .failure(let error):
                    self.catchHandler(error)
                }
            }
        } else if let blockBare = task.block as? NextCompletion {
            blockBare() {
                self.runBlock()
            }
        } else {
            assertionFailure("Block passed of unknown type!")
        }
    }
*/

}

/*
public class TaskChain<SuccessResult> {
    public typealias CompletionHandler<SuccessResult> = (Result<SuccessResult, Error>)->Void
    var completion: CompletionHandler<SuccessResult> = { _ in }

    enum Failures: Error {
        case firstBlockCanHaveNoParameters
    }
    public class AnyTask {
        let paramType: Any.Type
        let resultType: Any.Type

        init(paramType: Any.Type, resultType: Any.Type) {
            self.paramType = paramType
            self.resultType = resultType
        }
    }
    deinit {
        print("taskchain: deinit")
    }

//    public struct NoParameter {
//    }
    typealias NoParameter = Void
    var lastResult: Result<Any, Error> = .success(NoParameter.self)
    
    class TaskParam<Parameter,SuccessResult>: AnyTask {
        var block: (Parameter, CompletionHandler<SuccessResult>)->Void

        public init(_ block: @escaping (Parameter, CompletionHandler<SuccessResult>)->Void) {
            self.block = block
            super.init(paramType: Parameter.Type.self, resultType: SuccessResult.Type.self)
        }
    }
    class TaskNoParam<SuccessResult>: AnyTask {
        var block: (CompletionHandler<SuccessResult>)->Void

        public init(_ block: @escaping (CompletionHandler<SuccessResult>)->Void) {
            self.block = block
            super.init(paramType: Void.Type.self, resultType: SuccessResult.Type.self)
        }
    }

//    public typealias Task<Param,SuccessResult> = (Param)->Result<SuccessResult,Error>
    var taskList: [AnyTask] = []
    public func next<Param,SuccessResult>(_ block: @escaping (Param, CompletionHandler<SuccessResult>)->Void) {
        guard self.taskList.count == 0 else {
            self.completion(.failure(Failures.firstBlockCanHaveNoParameters))
            return
        }

        let task = TaskParam(block)
        self.taskList.append(task)

//        let paramType = type(of: task)

//        print("paramType: \(paramType)")
    }

    public func next<SuccessResult>(_ block: @escaping (CompletionHandler<SuccessResult>)->Void) {

        let task = TaskNoParam(block)
        self.taskList.append(task)
    }

    public func whenDone<Param>(_ block: @escaping (Result<Param,Error>)->Void) {

    }

    public func taskComplete() {

    }
}


*/
