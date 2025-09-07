//
//  EditProfileSheet.swift
//  IOS-expense-tracker
//

import SwiftUI

struct EditProfileSheet: View {
    let initialProfile: UserProfile
    var onSave: (UserProfile) -> Void
    @Environment(\.dismiss) private var dismiss
    
    @State private var name: String = ""
    @State private var timezone: String = TimeZone.current.identifier
    @State private var saving = false
    @State private var error: String?
    private let userAPI = UserAPI()

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Profile")) {
                    TextField("Name", text: $name)
                        .textInputAutocapitalization(.words)
                        .disableAutocorrection(true)
                    HStack {
                        Image(systemName: "globe")
                            .foregroundColor(.secondary)
                        TextField("Timezone (e.g., America/Los_Angeles)", text: $timezone)
                            .autocorrectionDisabled(true)
                            .textInputAutocapitalization(.never)
                    }
                    Button("Use Device Timezone: \(TimeZone.current.identifier)") {
                        timezone = TimeZone.current.identifier
                    }
                    .font(.footnote)
                }
                if let error {
                    Section {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill").foregroundColor(.red)
                            Text(error).foregroundColor(.red)
                        }
                    }
                }
            }
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .disabled(saving)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(saving ? "Saving..." : "Save") { Task { await save() } }
                        .disabled(saving)
                }
            }
            .onAppear {
                name = initialProfile.name ?? ""
                timezone = initialProfile.timezone ?? TimeZone.current.identifier
            }
        }
    }

    private func save() async {
        error = nil
        saving = true
        do {
            let updated = try await userAPI.updateProfile(name: name.isEmpty ? nil : name, timezone: timezone)
            saving = false
            onSave(updated)
            dismiss()
        } catch {
            saving = false
            self.error = error.localizedDescription
        }
    }
}

#Preview {
    EditProfileSheet(initialProfile: .init(id: "1", email: "a@b.com", name: "Jane Doe", provider: "google", timezone: "America/Los_Angeles")) { _ in }
}

