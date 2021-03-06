//
//  ChatUser.swift
//  LetsChatApp
//
//  Created by luane Niejelski on 7/14/22.
//

import Foundation

struct ChatUser: Codable, Identifiable {
    
    var id: String {uid}
    let uid, email, profileImageUrl: String
    
        init(data:[String: Any]) {
            self.uid = data["uid"] as? String ?? ""
            self.email = data["email"] as? String ?? ""
            self.profileImageUrl = data["profileImageUrl"] as? String ?? ""
       
    }
}
