import Foundation

actor ProfileImageLoader {
    private var cache: [URL: Data] = [:]

    func imageData(from url: URL) async -> Data? {
        if let cached = cache[url] {
            return cached
        }
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
                return nil
            }
            cache[url] = data
            return data
        } catch {
            return nil
        }
    }
}
