//
//  DCCJNetwork.swift
//  DCCJ_Swift_Project
//
//  Created by 龚欢 on 2018/1/16.
//  Copyright © 2018年 龚欢. All rights reserved.
//

import Foundation
import DCCJConfig

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

public extension Request {
    var host: String {
        return DCCJNetwork.shared.hostMaps[.production] ?? ""
    }
}

public protocol Client {
    func request<T: Request>(with r: T) -> (data: Future<Data>, task: URLSessionDataTask?)
}

public protocol DCCJNetworkDelegate: class {
    func errorCodeEqualTo201()
}

public protocol DCCJNetworkDataSource: class {
    func customHttpHeaders() -> Dictionary<String, String>
}

public enum NetworkEnvironment: Int {
    case qa = 0
    case cashier_staging
    case cashier_production
    case production
    case staging
    case message_production
}

public final class DCCJNetwork: Client {
    
    public static let shared = DCCJNetwork()
    private var urlSession: URLSession  = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        return URLSession(configuration: config)
    }()
    
    public var hostMaps: [NetworkEnvironment: String] = [:]
    
    private var LOGINKEY: String        = ""
    private var encryptF: (String) -> String = { $0 }
    
    public weak var delegate: DCCJNetworkDelegate?
    public weak var dataSource: DCCJNetworkDataSource?
    
    private init() {}
    
    public func config(hostMaps: [NetworkEnvironment: String], logKey: String, encryptMethod: @escaping (String) -> String) {
        if (!DCCJNetwork.shared.hostMaps.isEmpty || !DCCJNetwork.shared.LOGINKEY.isEmpty) {
            fatalError("Can not be modify values!!")
        }

        DCCJNetwork.shared.hostMaps = hostMaps
        DCCJNetwork.shared.LOGINKEY = logKey
        DCCJNetwork.shared.encryptF = encryptMethod
    }
    
    public func request<T>(with r: T) -> (data: Future<Data>, task: URLSessionDataTask?) where T : Request {
        var url: URL
        if r.path.hasPrefix("http") || r.path.hasPrefix("https") {
            url = URL(string: r.path)!
        } else if (!r.path.hasPrefix("http") && !r.path.hasPrefix("https") && !r.host.isEmpty) {
            url = URL(string: r.host.appending(r.path))!
        } else {
            fatalError("unknow host or path!!!")
        }
        
        let promise = Promise<Data>()
        
        guard let request = getRequest(type: r.method, initURL: url, httpBody: r.paramters, isSign: true) else {
            promise.reject(with: DataManagerError.failedRequest)
            return (data: promise, task: nil)
        }
        
        let task = self.urlSession.dataTask(with: request) { (data, response, error) in
            if let e = error {
                promise.reject(with: DataManagerError.customError(message: e.localizedDescription))
            } else if let data = data,  let response = response as? HTTPURLResponse {
                if response.statusCode == 200 {
                    do {
                        if let returnDic = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                            print(returnDic)
                            if self.isErrorCodeEqual201(returnDic).is201 {
                                if let callbackErrorCode201 = self.delegate?.errorCodeEqualTo201 { callbackErrorCode201() }
                                promise.reject(with: DataManagerError.customError(message: self.isErrorCodeEqual201(returnDic).errMsg))
                            } else if self.isSuccess(returnDic) {
                                promise.resolve(with: data)
                            } else {
                                promise.reject(with: DataManagerError.unknow)
                            }
                        } else {
                            promise.reject(with: DataManagerError.unknow)
                        }
                    } catch(let e) {
                        print(e)
                        promise.reject(with: DataManagerError.failedRequest)
                    }
                } else {
                    promise.reject(with: DataManagerError.failedRequest)
                }
            } else {
                promise.reject(with: DataManagerError.unknow)
            }
        }
        
        task.resume()
        
        return (data: promise, task: task)
    }
    
    private func isSuccess(_ d: [String: Any]) -> Bool {
        if let b = d["success"] as? Bool, b == true {
            return true
        }
        return false;
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
                    let signMd5  = DCCJNetwork.shared.encryptF(totalStr)
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
