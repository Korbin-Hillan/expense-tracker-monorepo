//
//  UserProfile.swift
//  IOS-expense-tracker
//
//  Created by Korbin Hillan on 8/24/25.
//

import Foundation

struct UserProfile: Decodable {
    let id: String
    let email: String?
    let name: String?
    let provider: String?
    let timezone: String?
}

struct UserProfileResponse: Decodable {
    let user: UserProfile
}
