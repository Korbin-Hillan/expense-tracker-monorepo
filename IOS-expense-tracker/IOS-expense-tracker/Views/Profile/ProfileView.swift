//
//  ProfileView.swift
//  IOS-expense-tracker
//
//  Created by Korbin Hillan on 8/24/25.
//

import SwiftUI

private enum LoadState { case loading, error(String), data(UserProfile) }


struct ProfileView: View {
    @State private var state: LoadState = .loading
    var onSignOut: () -> Void = {}

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                contentBody()
                    .padding(.horizontal, 20)
                
                Spacer(minLength: 100)
            }
        }
        .task { await loadProfile() }
        .refreshable { await loadProfile(force: true) }
    }

    @ViewBuilder
    private func contentBody() -> some View {
        switch state {
        case .loading:
            LoadingCard()
        case .error(let message):
            ErrorCard(message: message) {
                Task { await loadProfile(force: true) }
            }
        case .data(let profile):
            ProfileCard(profile: profile,
                        onRefresh: { Task { await loadProfile(force: true) } },
                        onSignOut: onSignOut)
        }
    }

    private func loadProfile(force: Bool = false) async {
        state = .loading

        guard let token = loadToken() else {
            state = .error("No session found. Please sign in again.")
            return
        }

        var req = URLRequest(url: URL(string: "http://192.168.0.119:3000/api/me")!)
        req.httpMethod = "GET"
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        do {
            let (data, resp) = try await URLSession.shared.data(for: req)
            guard let http = resp as? HTTPURLResponse else {
                state = .error("No HTTP response.")
                return
            }
            switch http.statusCode {
            case 200:
                let me = try JSONDecoder().decode(UserProfileResponse.self, from: data)
                state = .data(me.user)
            case 401:
                state = .error("Token invalid or expired. Please sign in again.")
            default:
                let body = String(data: data, encoding: .utf8) ?? "<non-UTF8>"
                state = .error("Server error \(http.statusCode): \(body)")
            }
        } catch {
            state = .error("Request failed: \(error.localizedDescription)")
        }
    }
}
