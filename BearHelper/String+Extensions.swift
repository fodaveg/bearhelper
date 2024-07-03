import Foundation

extension String {
    func addingPercentEncodingForRFC3986() -> String? {
        let unreserved = "-._~"
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: unreserved)
        return self.addingPercentEncoding(withAllowedCharacters: allowed) ?? ""
    }
}
