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
    case customError(message: String, errCode: Int)   // 自定义错误
    
    public var errorMessage: String {
        switch self {
        case .failedRequest:
            return "请求失败"
        case .invalidResponse:
            return "响应失败"
        case .unknow:
            return "未知错误"
        case .customError(let message, _):
            return message
        }
    }
    
    public var errorCode: Int {
        switch self {
        case .failedRequest:
            return -1024
        case .invalidResponse:
            return -1025
        case .unknow:
            return -1026
        case .customError(_, let code):
            return code
        }
    }
    
    public func error() -> NSError {
        return NSError(domain: self.errorMessage, code: self.errorCode, userInfo: nil)
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
    var host: String { get }
    var path: String { get }
    var method: HTTPMethod { get }
    var paramters: [String: Any] { get }
}

extension Request {
    var host: String {
        return DCCJNetwork.shared.hostMaps[.production] ?? ""
    }
}

public protocol Client {
    func requestBy<C: Codable, T: Request>(_ r: T, completion: @escaping (C?, DataManagerError?) -> Void)
}

public protocol DCCJNetworkDelegate: class {
    func errorCodeEqualTo201()
}

public protocol DCCJNetworkDataSource: class {
    func customHttpHeaders() -> Dictionary<String, String>
}

@objc public enum NetworkEnvironment: Int {
    case qa = 0
    case cashier_staging
    case cashier_production
    case production
    case staging
}

public final class DCCJNetwork: NSObject, Client {
    public static let shared = DCCJNetwork()
    private var urlSession: URLSession  = URLSession.shared
    
    public var hostMaps: [NetworkEnvironment: String] = [:]
    
    private var LOGINKEY: String        = ""
    private var encryptF: ((String) -> String)? = nil
    
    public weak var delegate: DCCJNetworkDelegate?
    public weak var dataSource: DCCJNetworkDataSource?
    
    private override init() {}
    
    public func config(hostMaps: [Int: String], logKey: String, encryptMethod: ((String) -> String)?) {
        if (!DCCJNetwork.shared.hostMaps.isEmpty || !DCCJNetwork.shared.LOGINKEY.isEmpty || DCCJNetwork.shared.encryptF != nil) {
            fatalError("Can not be modify values!!")
        }
        
        DCCJNetwork.shared.hostMaps  = Dictionary(uniqueKeysWithValues: hostMaps.map { key, value in (NetworkEnvironment(rawValue: key)!, value)})
        DCCJNetwork.shared.LOGINKEY = logKey
        DCCJNetwork.shared.encryptF = encryptMethod
    }
    
    public func requestBy<C, T>(_ r: T, completion: @escaping (C?, DataManagerError?) -> Void) where C : Decodable, C : Encodable, T : Request {
        var url: URL
        if r.path.hasPrefix("http") || r.path.hasPrefix("https") {
            url = URL(string: r.path)!
        } else if (!r.path.hasPrefix("http") && !r.path.hasPrefix("https") && !r.host.isEmpty) {
            url = URL(string: r.host.appending(r.path))!
        } else {
            fatalError("unknow host or path!!!")
        }
        guard let request = getRequest(type: r.method, initURL: url, httpBody: r.paramters, isSign: true) else { return }
        
        self.urlSession.dataTask(with: request) { (data, response, error) in
            if let _ = error {
                completion(nil, .failedRequest)
            } else if let data = data,  let response = response as? HTTPURLResponse {
                if response.statusCode == 200 {
                    do {
                        if let returnDic = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                            if self.isErrorCodeEqual201(returnDic).is201 {
                                if let callbackErrorCode201 = self.delegate?.errorCodeEqualTo201 { callbackErrorCode201() }
                                completion(nil, .customError(message: self.isErrorCodeEqual201(returnDic).errMsg, errCode: -9999))
                            } else {
                                let json = try JSONDecoder().decode(C.self, from: data)
                                completion(json, nil)
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
    
    private func isErrorCodeEqual201(_ d: [String: Any]) -> (is201: Bool, errMsg: String) {
        if let m = d["resultMessage"] as? String,
            let code = d["resultCode"] as? String,
            code == "201" {
            return (is201: true, errMsg: m)
        } else if let m = d["message"] as? String,
            let code = d["code"] as? String,
            code == "201" {
            return (is201: true, errMsg: m)
        }
        return (is201: false, errMsg: "")
    }
    
    
    // MARK: -- 生成Request
    private func getRequest(type: HTTPMethod, initURL: URL, httpBody: Dictionary<String, Any>? = nil, isSign: Bool = false) -> URLRequest? {
        guard let encrypt = DCCJNetwork.shared.encryptF else { return nil }
        var request = URLRequest(url: initURL)
        /*Add custom header fields*/
        if let headerDatas = self.dataSource?.customHttpHeaders() {
            for (key, value) in headerDatas where !key.isEmpty && !value.isEmpty {
                request.addValue(value, forHTTPHeaderField: key)
            }
        }
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpMethod = type == .GET ? "GET" : "POST"
        if type == .GET {
            
            if var urlComponents = URLComponents(url: initURL, resolvingAgainstBaseURL: false),
                let httpBody = httpBody,
                !httpBody.isEmpty {
                
                urlComponents.queryItems = [URLQueryItem]()
                
                for (key, value) in httpBody {
                    let queryItem = URLQueryItem(name: key, value: "\(value)".addingPercentEncoding(withAllowedCharacters: .urlHostAllowed))
                    urlComponents.queryItems?.append(queryItem)
                }
                request.url = urlComponents.url
            }
            
        } else if type == .POST {
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
                    let signMd5  = encrypt(totalStr)
                    request.addValue(signMd5, forHTTPHeaderField: "Signature")
                }
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
}




