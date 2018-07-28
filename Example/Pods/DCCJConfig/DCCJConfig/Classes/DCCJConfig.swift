//
//  DCCJConfig.swift
//  DCCJConfig
//
//  Created by 龚欢 on 2018/7/28.
//

import Foundation

public enum Result<Value, Error: Swift.Error> {
    case success(Value)
    case failure(Error)
}
