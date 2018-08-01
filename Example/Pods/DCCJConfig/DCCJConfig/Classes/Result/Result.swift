//
//  Result.swift
//  TestResult
//
//  Created by 龚欢 on 2018/7/31.
//  Copyright © 2018年 龚欢. All rights reserved.
//

import Foundation

/*
 ** 返回的数据类型
 */
public enum Result<Value> {
    case success(Value)
    case failure(Error)
}


/*
 ** Promise
 */
public class Future<Value> {
    fileprivate var result: Result<Value>? {
        // Observe whenever a result is assigned, and report it
        didSet { result.map(report) }
    }
    
    private lazy var callbacks = [(Result<Value>) -> Void]()
    
    public func observe(with callback: @escaping (Result<Value>) -> Void) {
        callbacks.append(callback)
        
        // If a result has already been set, call the callback directly
        result.map(callback)
    }
    
    private func report(result: Result<Value>) {
        for callback in callbacks {
            callback(result)
        }
    }
}

public extension Future {
    func chained<NextValue>(with closure: @escaping (Value) throws -> Future<NextValue>) -> Future<NextValue> {
        // Start by constructing a "wrapper" promise that will be returned from this method
        let promise = Promise<NextValue>()
        
        // Observe the current future
        observe { (result) in
            switch result {
            case .success(let value):
                do {
                    // Attempt to construct a new future given the value from the first one
                    let future = try closure(value)
                    
                    // Observe the "nested" future, and once it completes, resolve/reject the "wrapper" future
                    future.observe(with: { (result) in
                        switch result {
                        case .success(let value):
                            promise.resolve(with: value)
                        case .failure(let error):
                            promise.reject(with: error)
                        }
                    })
                } catch {
                    promise.reject(with: error)
                }
            case .failure(let error):
                promise.reject(with: error)
            }
        }
        
        return promise
    }
    
    func transformed<NextValue>(with closure: @escaping (Value) throws -> NextValue) -> Future<NextValue> {
        return chained(with: { (value) -> Future<NextValue> in
            return try Promise(value: closure(value))
        })
    }
}

public extension Future where Value == Data {
    func unboxed<NextValue: Codable>() -> Future<NextValue> {
        return transformed(with: { (value) -> NextValue in
            try JSONDecoder().decode(NextValue.self, from: value)
        })
    }
}

public class Promise<Value>: Future<Value> {
    public init(value: Value? = nil) {
        super.init()
        
        // If the value was already known at the time the promise was constructed, we can report the value directly
        result = value.map(Result.success)
    }
    
    public func resolve(with value: Value) {
        result = .success(value)
    }
    
    public func reject(with error: Error) {
        result = .failure(error)
    }
}
