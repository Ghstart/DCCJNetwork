//
//  Promise.swift
//  DCCJConfig
//
//  Created by 龚欢 on 2018/7/31.
//

import Foundation

class Promise<Value>: Future<Value> {
    init(value: Value? = nil) {
        super.init()
        
        // If the value was already known at the time the promist was constructed, we can report the value directly
        result = value.map(Result.value, NSError())
    }
    
    func resolve(with value: Value) {
        result = .value(value)
    }
    
    func reject(with error: Error) {
        result = .error(error)
    }
}

class Future<Value> {
    fileprivate var result: Result<Value, NSError>? {
        didSet { result.map(report) }
    }
    
    private lazy var callbacks = [(Result<Value, NSError>) -> Void]()
    
    func observe(with callback: @escaping (Result<Value, NSError>) -> Void) {
        callbacks.append(callback)
        
        // If a result has already been set, call the callback directly
        result.map(callback)
    }
    
    private func report(result: Result<Value, NSError>) {
        for callback in callbacks {
            callback(result)
        }
    }
}
