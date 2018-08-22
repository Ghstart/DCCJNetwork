//
//  DataManagerError.swift
//  TestResult
//
//  Created by 龚欢 on 2018/7/31.
//  Copyright © 2018年 龚欢. All rights reserved.
//

import Foundation

/*
 ** 返回错误数据类型
 */
public enum DataManagerError: Error {
    case failedRequest                                  // 请求失败
    case invalidResponse                                // 响应失败
    case unknow                                         // 未知错误
    case customError(message: String)                   // 自定义错误
    case systemError(e: Error)                          // 系统错误
    
    public var errorMessage: String {
        switch self {
        case .failedRequest:
            return "请求失败"
        case .invalidResponse:
            return "响应失败"
        case .unknow:
            return "未知错误"
        case .customError(let message):
            return message
        case .systemError(let e):
            return e.localizedDescription
        }
    }
}

extension DataManagerError: Equatable {
    public static func ==(lhs: DataManagerError, rhs: DataManagerError) -> Bool {
        switch (lhs, rhs) {
        case (.failedRequest, .failedRequest):
            return true
        case (.invalidResponse, .invalidResponse):
            return true
        case (.unknow, .unknow):
            return true
        case (.customError(let e), .customError(let s)) where e == s:
            return true
        case (.systemError(let e), .systemError(let s)) where e.localizedDescription == s.localizedDescription:
            return true
        default:
            return false
        }
    }
}

