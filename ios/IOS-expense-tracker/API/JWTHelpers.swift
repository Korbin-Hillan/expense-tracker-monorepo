// JWTHelpers.swift
import Foundation

enum JWTHelpers {
    static func expDate(_ jwt: String) -> Date? {
        let parts = jwt.split(separator: ".")
        guard parts.count >= 2 else { return nil }
        func decode(_ s: Substring) -> Data? {
            var str = String(s).replacingOccurrences(of: "-", with: "+")
                                 .replacingOccurrences(of: "_", with: "/")
            while str.count % 4 != 0 { str.append("=") }
            return Data(base64Encoded: str)
        }
        guard let payloadData = decode(parts[1]),
              let obj = try? JSONSerialization.jsonObject(with: payloadData) as? [String: Any],
              let exp = obj["exp"] as? Double else { return nil }
        return Date(timeIntervalSince1970: exp)
    }

    static func isExpired(_ jwt: String, skew: TimeInterval = 60) -> Bool {
        print("🕒 JWTHelpers: Checking if token is expired...")
        print("🔐 JWTHelpers: Token: \(jwt.prefix(50))...")
        
        guard let exp = expDate(jwt) else { 
            print("❌ JWTHelpers: Could not parse expiration date from token")
            return true 
        }
        
        let now = Date()
        let isExpired = now.addingTimeInterval(skew) >= exp
        
        print("🕒 JWTHelpers: Token expires at: \(exp)")
        print("🕒 JWTHelpers: Current time: \(now)")
        print("🕒 JWTHelpers: Token is expired: \(isExpired)")
        
        return isExpired
    }
}
