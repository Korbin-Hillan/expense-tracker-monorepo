// AuthClient.swift
import Foundation

struct EmailLoginResponse: Codable {
    let token: String
    let refresh_token: String
    struct User: Codable { let id: String; let email: String?; let name: String? }
    let user: User
}

struct RegisterResponse: Codable {
    let token: String
    let refresh_token: String
    struct User: Codable { let id: String; let email: String?; let name: String? }
    let user: User
    let message: String?
}

enum AuthError: LocalizedError {
    case notAuthenticated
    case invalidCredentials
    case userExists
    case weakPassword
    case invalidEmail
    case server(String)
    case networkError
    case decodingError
    case badResponse
    var errorDescription: String? {
        switch self {
        case .notAuthenticated: return "You’re not signed in."
        case .invalidCredentials: return "Invalid email or password."
        case .userExists: return "An account with this email already exists."
        case .weakPassword: return "Password must be at least 6 characters long."
        case .invalidEmail: return "Please enter a valid email address."
        case .server(let msg): return msg
        case .networkError: return "Network error. Please check your connection."
        case .decodingError: return "Data error. Please try again."
        case .badResponse: return "Unexpected server response."
        }
    }
}

final class AuthClient {
    let base = URL(string: "http://172.16.225.231:3000")! // ← your API base
    
    func testConnection() async {
        print("🌐 AuthClient: Testing connection to \(base)")
        do {
            let (data, response) = try await URLSession.shared.data(from: base)
            if let httpResponse = response as? HTTPURLResponse {
                print("✅ Connection test: Status \(httpResponse.statusCode)")
                print("📥 Response: \(String(data: data, encoding: .utf8) ?? "<no data>")")
            }
        } catch {
            print("❌ Connection test failed: \(error)")
        }
    }
    
    private func isValidEmail(_ email: String) -> Bool {
        let emailRegEx = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPred = NSPredicate(format:"SELF MATCHES %@", emailRegEx)
        return emailPred.evaluate(with: email)
    }
    
    private func isValidPassword(_ password: String) -> Bool {
        return password.count >= 6
    }

    func loginWithEmail(email: String, password: String) async throws -> EmailLoginResponse {
        print("🔐 AuthClient: Starting login attempt for email: \(email)")
        
        // Validate inputs
        guard isValidEmail(email) else {
            print("❌ AuthClient: Invalid email format: \(email)")
            throw AuthError.invalidEmail
        }
        guard isValidPassword(password) else {
            print("❌ AuthClient: Password too weak (length: \(password.count))")
            throw AuthError.weakPassword
        }
        
        let loginURL = base.appendingPathComponent("/api/auth/session")
        print("🌐 AuthClient: Login URL: \(loginURL)")
        
        var req = URLRequest(url: loginURL)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestBody = ["email": email, "password": password]
        req.httpBody = try JSONEncoder().encode(requestBody)
        
        print("📤 AuthClient: Sending login request...")
        print("📤 Request body: \(requestBody)")

        do {
            let (data, resp) = try await URLSession.shared.data(for: req)
            guard let http = resp as? HTTPURLResponse else {
                print("❌ AuthClient: No HTTP response received")
                throw AuthError.badResponse
            }

            print("📥 AuthClient: Response status code: \(http.statusCode)")
            print("📥 Response body: \(String(data: data, encoding: .utf8) ?? "<no data>")")

            if (200...299).contains(http.statusCode) {
                let login = try JSONDecoder().decode(EmailLoginResponse.self, from: data)
                // Use the global keychain functions instead of UserDefaults
                saveToken(login.token)
                saveRefreshToken(login.refresh_token)
                print("✅ AuthClient: Login successful, tokens saved to Keychain")
                return login
            } else {
                struct ErrMsg: Codable { let error: String? }
                let msg = (try? JSONDecoder().decode(ErrMsg.self, from: data).error) ?? "Login failed."
                print("❌ AuthClient: Login failed - \(msg)")
                if http.statusCode == 401 { throw AuthError.invalidCredentials }
                throw AuthError.server(msg)
            }
        } catch {
            print("❌ AuthClient: Network error during login: \(error)")
            if error is AuthError {
                throw error
            } else if error is DecodingError {
                throw AuthError.decodingError
            } else {
                throw AuthError.networkError
            }
        }
    }
    
    func registerWithEmail(email: String, password: String, name: String = "") async throws -> RegisterResponse {
        print("📝 AuthClient: Starting registration attempt for email: \(email)")
        
        // Validate inputs
        guard isValidEmail(email) else {
            print("❌ AuthClient: Invalid email format for registration: \(email)")
            throw AuthError.invalidEmail
        }
        guard isValidPassword(password) else {
            print("❌ AuthClient: Password too weak for registration (length: \(password.count))")
            throw AuthError.weakPassword
        }
        
        let registerURL = base.appendingPathComponent("/api/auth/register")
        print("🌐 AuthClient: Register URL: \(registerURL)")
        
        var req = URLRequest(url: registerURL)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestBody: [String: Any] = [
            "email": email,
            "password": password,
            "name": name.isEmpty ? NSNull() : name
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        print("📤 AuthClient: Sending registration request...")
        print("📤 Request body: \(requestBody)")

        do {
            let (data, resp) = try await URLSession.shared.data(for: req)
            guard let http = resp as? HTTPURLResponse else {
                print("❌ AuthClient: No HTTP response received for registration")
                throw AuthError.badResponse
            }

            print("📥 AuthClient: Registration response status code: \(http.statusCode)")
            print("📥 Response body: \(String(data: data, encoding: .utf8) ?? "<no data>")")

            if (200...299).contains(http.statusCode) {
                let register = try JSONDecoder().decode(RegisterResponse.self, from: data)
                saveToken(register.token)
                saveRefreshToken(register.refresh_token)
                print("✅ AuthClient: Registration successful, tokens saved to Keychain")
                return register
            } else {
                struct ErrMsg: Codable { let error: String? }
                let msg = (try? JSONDecoder().decode(ErrMsg.self, from: data).error) ?? "Registration failed."
                print("❌ AuthClient: Registration failed - \(msg)")
                if http.statusCode == 409 { throw AuthError.userExists }
                throw AuthError.server(msg)
            }
        } catch {
            print("❌ AuthClient: Network error during registration: \(error)")
            if error is AuthError {
                throw error
            } else if error is DecodingError {
                throw AuthError.decodingError
            } else {
                throw AuthError.networkError
            }
        }
    }
    
    func loginOrRegister(email: String, password: String, name: String = "") async throws -> EmailLoginResponse {
        print("🚀 AuthClient: Starting unified auth attempt for: \(email)")
        
        // Validate inputs
        guard isValidEmail(email) else {
            print("❌ AuthClient: Invalid email format: \(email)")
            throw AuthError.invalidEmail
        }
        guard isValidPassword(password) else {
            print("❌ AuthClient: Password too weak (length: \(password.count))")
            throw AuthError.weakPassword
        }
        
        let authURL = base.appendingPathComponent("/api/auth/session")
        print("🌐 AuthClient: Auth URL: \(authURL)")
        
        var req = URLRequest(url: authURL)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        
        let requestBody = [
            "email": email,
            "password": password,
            "name": name.isEmpty ? nil : name
        ].compactMapValues { $0 }
        
        req.httpBody = try JSONEncoder().encode(requestBody)
        
        print("📤 AuthClient: Sending unified auth request...")
        print("📤 Request body: \(requestBody)")

        do {
            let (data, resp) = try await URLSession.shared.data(for: req)
            guard let http = resp as? HTTPURLResponse else {
                print("❌ AuthClient: No HTTP response received")
                throw AuthError.badResponse
            }

            print("📥 AuthClient: Response status code: \(http.statusCode)")
            print("📥 Response body: \(String(data: data, encoding: .utf8) ?? "<no data>")")

            if (200...299).contains(http.statusCode) {
                let login = try JSONDecoder().decode(EmailLoginResponse.self, from: data)
                saveToken(login.token)
                saveRefreshToken(login.refresh_token)
                print("✅ AuthClient: Auth successful, tokens saved to Keychain")
                return login
            } else {
                struct ErrMsg: Codable { let error: String? }
                let msg = (try? JSONDecoder().decode(ErrMsg.self, from: data).error) ?? "Authentication failed."
                print("❌ AuthClient: Auth failed - \(msg)")
                if http.statusCode == 401 { throw AuthError.invalidCredentials }
                throw AuthError.server(msg)
            }
        } catch {
            print("❌ AuthClient: Network error during auth: \(error)")
            if error is AuthError {
                throw error
            } else if error is DecodingError {
                throw AuthError.decodingError
            } else {
                throw AuthError.networkError
            }
        }
    }
    
    // MARK: - Token Management
    // All token management now handled by global Keychain functions from Security.swift
}
