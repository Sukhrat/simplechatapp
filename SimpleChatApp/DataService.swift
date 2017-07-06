//
//  DataService.swift
//  SimpleChatApp
//
//  Created by Sukhrat on 05.07.17.
//  Copyright © 2017 Sukhrat. All rights reserved.
//

import Foundation
import Firebase

class DataService {
    
    static let dataService = DataService()
    
    private var _BASE_REF = BASE_URL
    private var _USER_REF = "\(BASE_URL)users"
    private var _POST_REF = "\(BASE_URL)posts"
    
    var BASE_REF: String {
        
        return _BASE_REF
        
    }
    
    var USER_REF: String {
        
        return _USER_REF
        
    }
    
    var POST_REF: String {
        
        return _POST_REF
        
    }
}
