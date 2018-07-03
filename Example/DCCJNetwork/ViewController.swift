//
//  ViewController.swift
//  DCCJNetwork
//
//  Created by Ghstart on 06/25/2018.
//  Copyright (c) 2018 Ghstart. All rights reserved.
//

import UIKit
import DCCJNetwork

class ViewController: UIViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // config host、logkey、encrypt function
        DCCJNetwork.shared.config(host: "https://www.host.com/", logKey: "You-Private-Key") { (encrypt) -> String in
            // encrypt
            return ""
        }
        

        // send request
        DCCJNetwork.shared.requestBy(BankCardsRequest.bankLists(accessToken: "token")) { (data, error) in
            print(data ?? "no data")
            print(error ?? "no error")
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
