<p align="center">
<a href="https://github.com/dannys42/ClosureChain/actions?query=workflow%3ASwift"><img src="https://github.com/dannys42/ClosureChain/workflows/Swift/badge.svg" alt="build status"></a>
<img src="https://img.shields.io/badge/os-macOS-green.svg?style=flat" alt="macOS">
<img src="https://img.shields.io/badge/os-iOS-green.svg?style=flat" alt="iOS">
<img src="https://img.shields.io/badge/os-linux-green.svg?style=flat" alt="Linux">
<a href="LICENSE"><img src="https://img.shields.io/badge/license-Apache2-blue.svg?style=flat" alt="Apache 2"></a>
<br/>
<a href="https://swiftpackageindex.com/dannys42/ClosureChain"><img src="https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fdannys42%2FClosureChain%2Fbadge%3Ftype%3Dswift-versions"></a>
<a href="https://swiftpackageindex.com/dannys42/ClosureChain"><img src="https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fdannys42%2FClosureChain%2Fbadge%3Ftype%3Dplatforms"></a>
</p>

# ClosureChain

`ClosureChain` simplifies sequential async completion methods for Swift.  It provides a familiar try-catch pattern for sequential async methods.


## Installation

### Swift Package Manager
Add the `ClosureChain` package to the dependencies within your application's `Package.swift` file.  Substitute "x.y.z" with the latest `ClosureChain` [release](https://github.com/dannys42/ClosureChain/releases).

```swift
.package(url: "https://github.com/dannys42/ClosureChain.git", from: "x.y.z")
```

Add `ClosureChain` to your target's dependencies:

```swift
.target(name: "example", dependencies: ["ClosureChain"]),
```

### Cocoapods

Add `ClosureChain` to your Podfile:

```ruby
pod `ClosureChain`
```


## Usage

Typically in Swift, network or other async methods make use of completion handlers to streamline work.  A typical method signature looks like this:

```swift
    func someAsyncMethod(_ completion: (Data?, Error?)->Void) {
    }
```

However, this can become difficult to manage when you need to perform a number of async functions, each relying on success data from the previous call.

Normally this requires nesting the async methods or the use of a state machine.  Both of which can be difficult to reason about.

Closure Chains simplify this by allowing the developer to treat each async call as linkage of throwable closures. (i.e. links in a chain), with a single `catch` closure to manage any errors.

### Simple Example

```swift
    let chain = ClosureChain()
    chain.try { link in
        someAsyncMethod() { data, error in 
            if let error = error {
                link.throw(error)                   // use `link.throw()` since completion block is not throwable
            }
            guard let data = data else {
                link.throw(Failure.missingDdata)    // use `link.throw()` since completion block is not throwable
                return
            }
            // do something with `data`

            link.success()                          // required
        }
    }
    chain.catch { error in
        // error handler
    }
    chain.start()                                   // required to start executing links
```

Note the familiar `try-catch` pattern.  However `try` is perfomed on the chain `chain`, and the `throw` is performed on the `link`.  As a convenience, you can simply use the Swift `throw` command directly within a try-block.

There are two additional required functions:

 - `link.success()` is required to let `ClosureChain` know when an async task is complete
 - `chain.start()` is required to kick off execution of the chain.  No links will be executed until the `.start()` command is initiated.

### Passing data

The above is not very useful when we only have one async operation.  But what if we have several async operations that we wish to perform.  For example imagine we are attempt to perform this sequence of tasks:

 * Get raw image data from network
 * Convert raw data to a UIImage object.  Perhaps we have a long running async task here that will perform decryption, digital signature verification, and JSON deserialization
 * Do more background processing on UIImage
 * Notify the user we're done

For simplicity, we'll assume all our async methods are using the `Result` protocol.

This is how this might look with `ClosureChain`:

```swift
function closureChainExample() {
    let chain = ClosureChain()
    chain.try { link in
        getDataAsync() { result: Result<Data,Error> in  // Result type is provided solely for context in this example
            switch result {
            case .failure(let error):
                link.throw(error)       // use link.throw() since completion handler is not throwable
            case .success(let data):
                link.success(data)      // Pass `data` to the next link
            }
        }
    }

    chain.try { data: Data, link in     // `data` type must match prior link.success() (this check is performed at run-time)
        convertToUIImage(data) { result: Result<UIImage,Error> in   // Result type is provided solely for context in this example
            switch result {
            case .failure(let error):
                link.throw(error)       // use link.throw() since completion handler is not throwable
            case .success(let uiimage):
                link.success(uiimage)   // Pass `uiimage` to the next link
            }
        }
    }

    chain.try { image: UIImage, link in // `image` type must match prior link.success()
        processImage(image) { error: Error? in      // Error type is provided solely for context in this example
            do {
                if let error = error {
                    throw(error)        // can use do-catch to allow `throws` to pass to `link.throw()`
                }
                link.success()          // Go to next link with no passed data
            } catch {
                link.throw(error)
            }
        }
    }
    chain.try { link in                 // It is safe to ignore the passed parameter from the last `link.success()`
        // Notify the user we're done
        link.success()                  // Required even though this is the last link
    }

    chain.catch { error in
        // error handler
    }
    chain.start()                       // Required to start executing links
}
```

Notes:
 * `chain` can be safely allowed to fall out-of-scope.  `chain` and the
   associated closures will not be released from memory until `link.success()`
   in the last link is called.
 * ClosureChains make no use of DispatchQueue or OperationQueue.  Therefore
   there is no guarantee that any link is executing on any specific
   queue/thread.

### Results can be Even Better

If your async methods have completion handlers that take a single Result parameter, as in the above example, you can further reduce your code:


```swift
function closureChainExample() {
    let chain = ClosureChain()
    chain.try { link in
        getDataAsync() { result: Result<Data,Error> in  // Result type is provided solely for context in this example
            link.return(result)           // calls link.throw() or link.success() appropriately
        }
    }

    chain.try { data: Data, link in     // `data` type must match prior link.success() (this check is performed at run-time)
        convertToUIImage(data) { result: Result<UIImage,Error> in   // Result type is provided solely for context in this example
            link.return(result)           // calls link.throw() or link.success() appropriately
        }
    }

    chain.try { image: UIImage, link in // `image` type must match prior link.success()
        processImage(image) { result: Result<UIImage,Error> in      // Result type is provided solely for context in this example
            link.return(result)
        }
    }
    chain.try { link in                 // It is safe to ignore the passed parameter from the last `link.success()`
        // Notify the user we're done
        link.success()                  // Required even though this is the last link
    }

    chain.catch { error in
        // error handler
    }
    chain.start()                       // Required to start executing links
}
```


## API Documentation

For more information visit our [API reference](https://dannys42.github.io/ClosureChain/).

## License
This library is licensed under Apache 2.0. The full license text is available in [LICENSE](LICENSE).
