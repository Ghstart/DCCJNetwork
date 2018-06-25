//
//  URLSessionProtocol.swift
//  DCCJ_Swift_Project
//
//  Created by 龚欢 on 2018/1/19.
//  Copyright © 2018年 龚欢. All rights reserved.
//

import Foundation

public typealias DataTaskHandler = (Data?, URLResponse?, Error?) -> Void

public protocol URLSessionProtocol {
    func dataTask(with request: URLRequest, completionHandler: @escaping DataTaskHandler) -> URLSessionDataTaskProtocol
}
