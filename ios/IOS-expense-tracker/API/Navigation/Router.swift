//
//  Router.swift
//  IOS-expense-tracker
//

import Foundation

final class Router: ObservableObject {
    static let shared = Router()

    @Published var selected: Screen = .Home
    @Published var recentFilter: RecentFilter? = nil
}

struct RecentFilter {
    var category: String?
    var startDate: Date?
    var endDate: Date?
}

