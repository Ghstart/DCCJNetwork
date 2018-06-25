//
//  DCCJNetwork.swift
//  DCCJ_Swift_Project
//
//  Created by 龚欢 on 2018/1/16.
//  Copyright © 2018年 龚欢. All rights reserved.
//

import Foundation

public enum DataManagerError: Error {
    case failedRequest                  // 请求失败
    case invalidResponse                // 响应失败
    case unknow                         // 未知错误
    case customError(message: String)   // 自定义错误
    
    public var errorMessage: String {
        switch self {
        case .failedRequest:
            return "请求失败"
        case .invalidResponse:
            return "相应失败"
        case .unknow:
            return "未知错误"
        case .customError(let message):
            return message
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
        default:
            return false
        }
    }
}


public enum HTTPMethod {
    case GET
    case POST
}

public protocol Request {
    var path: String { get }
    var method: HTTPMethod { get }
    var paramters: [String: Any] { get }
}

public protocol Client {
    var host: String { get }
    func requestBy<T: Request>(_ r: T, completion: @escaping (Data?, DataManagerError?) -> Void)
}

public struct Config {
    static func isUITesting() -> Bool {
        return ProcessInfo.processInfo.arguments.contains("UI-Testing")
    }
    
    static var urlSession: URLSessionProtocol = {
        if isUITesting() {
            return BankCardsListURLSession()
        } else {
            return URLSession.shared as! URLSessionProtocol
        }
    }()
}

public class BankCardsListURLSession: URLSessionProtocol {
    public func dataTask(with request: URLRequest, completionHandler: @escaping DataTaskHandler) -> URLSessionDataTaskProtocol {
        return DarkCardsURLSessionDataTask(request: request, completon: completionHandler)
    }
}

public class DarkCardsURLSessionDataTask: URLSessionDataTaskProtocol {
    private let request: URLRequest
    private let completion: DataTaskHandler
    
    init(request: URLRequest, completon: @escaping DataTaskHandler) {
        self.request = request
        self.completion = completon
    }
    
    public func resume() {
        let json = ProcessInfo.processInfo.environment["FakeJSON"]
        if let json = json {
            let response = HTTPURLResponse(url: request.url!,
                                           statusCode: 200,
                                           httpVersion: nil,
                                           headerFields: nil)
            
            let data = json.data(using: .utf8)!
            
            
            completion(data, response, nil)
        }
    }
}

public final class DCCJNetwork: Client {
    internal let urlSession: URLSessionProtocol
    static let shared = DCCJNetwork(urlSession: Config.urlSession)
    public var host: String = ""
    
    public var LOGINKEY: String = ""
    public var MD5F    : (String) -> String = DCCJNetwork.shared.md5
    
    internal init(urlSession: URLSessionProtocol) {
        self.urlSession = urlSession
    }
    
    func config(host: String, logKey: String, md5F: @escaping (String) -> String) {
        DCCJNetwork.shared.host     = host
        DCCJNetwork.shared.LOGINKEY = logKey
        DCCJNetwork.shared.MD5F     = md5F
    }
    
    public func requestBy<T: Request>(_ r: T, completion: @escaping (Data?, DataManagerError?) -> Void) {
        let url = URL(string: host.appending(r.path))!
        guard let request = getRequest(type: r.method, initURL: url, httpBody: r.paramters, isSign: true) else { return }
        
        self.urlSession.dataTask(with: request) { (data, response, error) in
            if let _ = error {
                completion(nil, .failedRequest)
            } else if let data = data,  let response = response as? HTTPURLResponse {
                if response.statusCode == 200 {
                    do {
                        if let returnDic = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                            if let message = returnDic["resultMessage"] as? String,
                                let code = returnDic["resultCode"] as? Int,
                                code == 201 {
                                // 清除所有登录信息
                                // UserManager.shared.clear()
                                completion(nil, .customError(message: message))
                            } else {
                                completion(data, nil)
                            }
                        } else {
                            completion(nil, .unknow)
                        }
                    } catch {
                        completion(nil, .invalidResponse)
                    }
                } else {
                    completion(nil, .failedRequest)
                }
            } else {
                completion(nil, .unknow)
            }
        }.resume()
    }

    // MARK: -- 生成Request
    private func getRequest(type: HTTPMethod, initURL: URL, httpBody: Dictionary<String, Any>? = nil, isSign: Bool = false) -> URLRequest? {
        
        var request = URLRequest(url: initURL)
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpMethod = type == .GET ? "GET" : "POST"
        if let paramters = httpBody,
            let httpBodyData = try? JSONSerialization.data(withJSONObject: paramters, options: []) {
            request.httpBody = httpBodyData
            
            // 判断是否需要签名
            if paramters.count > 0 && isSign {
                let pathURL = initURL
                let pathStr = pathURL.query
                
                let paramStr = self.calSignStr(paramters)
                guard let encodeStr = paramStr.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else { return nil }
                
                var totalStr = encodeStr
                if let pathStr = pathStr {
                    totalStr = "\(String(describing: pathStr))&\(encodeStr)"
                }
                let signMd5  = DCCJNetwork.shared.MD5F(totalStr)
                request.addValue(signMd5, forHTTPHeaderField: "Signature")
            }
        }

        return request
    }
    
    // Sign加密
    private func calSignStr(_ params: [String: Any]) -> String {
        let sortedKeys = Array(params.keys).sorted { $0 < $1 }
        
        var keyValues = [String]()
        for k in sortedKeys {
            if let value = params[k] {
                let keyAndValue = "\(k)=\(value)"
                keyValues.append(keyAndValue)
            }
        }
        
        var kvAll: String = ""
        for str in keyValues {
            if str == keyValues.last {
                kvAll.append(str)
            } else {
                kvAll.append("\(str)&")
            }
        }
        
        kvAll.append(DCCJNetwork.shared.LOGINKEY)
        
        return kvAll
    }
    
    private func md5(_: String) -> String {
        return ""
    }
}


