//
//  ViewController.swift
//  DCCJNetwork
//
//  Created by Ghstart on 06/25/2018.
//  Copyright (c) 2018 Ghstart. All rights reserved.
//

import UIKit
import DCCJNetwork
import DCCJConfig

class ViewController: UIViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // config host、logkey、encrypt function
        // config this at Appdelegate didFinishedLaunch method
        DCCJNetwork().config(hostMaps: [NetworkEnvironment.qa: "http://qa",
                                             NetworkEnvironment.cashier_production: "http://cashier_prodution",
                                             NetworkEnvironment.cashier_staging: "http://cashier_staging"],
                                  logKey: "logKey") { (m) -> String in
                                    return "\(m)+signed.."
        }
        
        // Send request and return data
        DCCJNetwork().request(with: BankCardsRequest.bankLists(accessToken: "token")).data.observe { (result) in
        
            switch result {
            case .success(let v):
                print(v)
            case .failure(let e):
                let error = e as! DataManagerError
                switch error {
                case .customError(let message):
                    print(message)
                case .failedRequest:
                    print("failedRequest")
                case .invalidResponse:
                    print("invalidResponse")
                case .unknow:
                    print("unknow")
                case .systemError(let e):
                    print(e.localizedDescription)
                }
            }
            
        }
        
        // Send request and return model
        DCCJNetwork().request(with: BankCardsRequest.bankLists(accessToken: "token")).data.unboxed().observe { (result: Result<BankCardsResponse>) in
            
            switch result {
            case .success(let v):
                print(v)
            case .failure(let e):
                let error = e as! DataManagerError
                switch error {
                case .customError(let message):
                    print(message)
                case .failedRequest:
                    print("failedRequest")
                case .invalidResponse:
                    print("invalidResponse")
                case .unknow:
                    print("unknow")
                case .systemError(let e):
                    print(e.localizedDescription)
                }
            }
        }
    }
}


public enum BankCardsRequest {
    case bankLists(accessToken: String)
    case checkPayPassword(payPassword: String, accessToken: String)
    case checkBin(cardNumber: String)
    case checkValidity(cardNumber: String)
}

extension BankCardsRequest: Request {
    
    public var method: HTTPMethod { return .POST }
    
    public var paramters: [String : Any] {
        switch self {
        case .bankLists(let accessToken):
            return ["accessToken": accessToken]
        case .checkPayPassword(let payPassword, let accessToken):
            return ["payPassword": payPassword, "accessToken": accessToken]
        case .checkBin(let cardNumber):
            return ["cardNumber": cardNumber]
        case .checkValidity(let cardNumber):
            return ["cardNumber": cardNumber]
        }
    }
    
    public var path: String {
        switch self {
        case .bankLists:
            return "api.php/getBankInfo"
        case .checkPayPassword:
            return "api.php/payPwdCheck"
        case .checkBin:
            return "cher.checkCardBin"
        case .checkValidity:
            return "cht=app.Cashier.checkBankCardValidity"
        }
    }
}

struct BankCardsResponse: Codable {
    
}
