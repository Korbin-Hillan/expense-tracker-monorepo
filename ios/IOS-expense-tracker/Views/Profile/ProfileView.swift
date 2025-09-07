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
    private let userAPI = UserAPI()

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
                        onRefresh: { 
                            Task { 
                                await loadProfile(force: true)
                            } 
                        },
                        onSignOut: onSignOut)
        }
    }

    private func loadProfile(force: Bool = false) async {
        state = .loading

        do {
            let me = try await userAPI.me()
            state = .data(me)
        } catch let e as UserAPIError {
            state = .error(e.localizedDescription)
        } catch {
            state = .error("Request failed: \(error.localizedDescription)")
        }
    }
}
