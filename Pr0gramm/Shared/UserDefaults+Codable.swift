import Foundation

extension UserDefaults {
    func decoded<T: Decodable>(_ type: T.Type, forKey key: String) -> T? {
        data(forKey: key).flatMap { try? JSONDecoder().decode(type, from: $0) }
    }

    func setEncoded<T: Encodable>(_ value: T, forKey key: String) {
        set(try? JSONEncoder().encode(value), forKey: key)
    }
}
