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

Closure Chains simplify this by allowing the developer to treat each async call as a `try` block (also referred to as a `Link` in a `ClosureChain`) with a single `catch` block to manage any errors.

### Simple Example

```swift
   let cc = ClosureChain()
   cc.try { link in
   		someAsyncMethod() { data, error in 
   			if let error = error {
   				link.throw(error)
   			}
   			guard let data = data else {
   				link.throw(Failure.missingDdata)
   				return
			}
			// do something with `data`

	   		link.success() // required
   		}
   }
   cc.catch { error in
   		// error handler
   }
   cc.start() 	// required
```

Note the familiar `try-catch` pattern.  However `try` is perfomed on the chain `cc`, and the `throw` is performed on the `link`.  As a convenience, you can simply use the Swift `throw` command directly within a try-block.

There are two additional required functions:

 - `link.success()` is required to let `ClosureChain` know when an async task is complete
 - `cc.start()` is required to kick off execution of the chain.  No try blocks will be executed until the `.start()` command is initiated.

### Passing data

The above is not very useful when we only have one async operation.  But what if we have several async operations that we wish to perform.  For example imagine we are attempt to perform this sequence of tasks:

 * Get raw image data from network
 * Convert raw data to a UIImage object.  Perhaps we have a long running async task here that will perform decryption, digital signature verification, and JSON deserialization
 * Save the UIImage to a remote data-store

For simplicity, we'll assume all our async methods are using the `Result` protocol.

This is how this might look with `ClosureChain`:

```swift
function closureChainExample() {
   let cc = ClosureChain()
   cc.try { link in
   		getDataAsync() { result: Result<Data,Error> in  // result type is provided solely for context
   			switch result {
   				case .failure(let error):
   					throw error				// C1
   				case .success(let data):
   					link.success(data)		// C2
   			}
   		}
   }
   
   cc.try { data: Data, link in			    // C3
   		convertToUIImage(data) { result: Result<UIImage,Error> in // result type is provided solely for context
   			switch result {
   				case .failure(let error):
   					throw error
   				case .success(let uiimage):
   					link.success(uiimage)	// C4
   			}
   		}
   }
   
   cc.try { data: Data, link in
   		saveToDataStore(data) { error: Error? in // result type is provided solely for context
   			if let error = error {
   				throw error
   			}
   			link.success()					// C5
   		}
   }
   
   cc.catch { error in
   		                                    // error handler
   }
   cc.start() 	                            // C6
}                                           // C7
```

* [C1] we can use `throw` directly in a try block
* [C2] the data is passed to [C3] as a typed parameter.  (This type-check is performed at run-time.)
* [C3] `data` must be declared with a type specified.
* [C4] now passes a different data type to the next block
* [C5] `.success()` must be called at the completion of the try-block, but need not pass any data.
* [C6] `.start()` is required to execute try-blocks.  No blocks will be executed until this is called.
* [C7] `cc` can be safely allowed to fall out-of-scope.  It does not need to be retained in a containing class variable.

## API Documentation

For more information visit our [API reference](https://dannys42.github.io/ClosureChain/).

## License
This library is licensed under Apache 2.0. The full license text is available in [LICENSE](LICENSE).
