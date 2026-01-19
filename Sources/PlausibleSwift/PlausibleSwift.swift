import Foundation

/// PlausibleSwift is an implementation of the Plausible Analytics REST events API as described here: https://plausible.io/docs/events-api
public struct PlausibleSwift {
    
    /// The domain configured for analytics inside Plausible eg `app://5calls.org`
    ///
    /// Must begin with one of  `http://`, `https://` or `app://`.
    public private(set) var domain: URL
    
    private var domainHost: String
    
    /// The Plausible server.
    private var server: URL
    
    private var plausibleAPIEventURL: URL {
        return server.appendingPathComponent("/api/event")
    }

    /// Initializes a plausible object used for sending events to the Plausible server.
    /// Throws an `invalidServer` or `invalidDomain` error if the server or domain you pass
    /// cannot be turned into a URL
    /// - Parameters:
    ///     - server: the Plausible server. Defaults to the hosted Plausible service.
    ///     - domain: a fully qualified domain (including scheme) representing a site you have set up in Plausible, such as `app://5calls.org`.
    public init(server: String = "https://plausible.io", domain: String) throws {
        // ensure correctness of the server and domain
        guard let serverUrl = URL(string: server),
            ["http", "https"].contains(serverUrl.scheme) else {
            throw PlausibleError.invalidServer
        }
        
        // try to craft a URL out of our domain to ensure correctness
        guard let domainUrl = URL(string: domain),
            ["http", "https", "app"].contains(domainUrl.scheme),
            let domainHost = domainUrl.host else {
            throw PlausibleError.invalidDomain
        }
        
        self.server = serverUrl
        self.domain = domainUrl
        self.domainHost = domainHost
    }
    
    /// Sends a pageview event to Plausible for the specified path
    /// - Parameters:
    ///     - path: a URL path to use as the pageview location (as if it was viewed on a website). There doesn't have to be anything served at this URL.
    ///     - properties: (optional) a dictionary of key-value pairs that will be attached to this event
    public func trackPageview(path: String, properties: [String: String] = [:]) {
        plausibleRequest(name: "pageview", path: path, properties: properties)
    }

    /// Sends a named event to Plausible for the specified path
    /// - Parameters:
    ///     - event: an arbitrary event name for your analytics.
    ///     - path: a URL path to use as the pageview location (as if it was viewed on a website). There doesn't have to be anything served at this URL.
    ///     - properties: (optional) a dictionary of key-value pairs that will be attached to this event
    /// Throws an `eventIsPageview` error if you try to specific the event name as `pageview` which may indicate that you're holding it wrong.
    public func trackEvent(event: String, path: String, properties: [String: String] = [:]) throws {
        guard event != "pageview" else {
            throw PlausibleError.eventIsPageview
        }
        
        plausibleRequest(name: event, path: path, properties: properties)
    }
    
    private func plausibleRequest(name: String, path: String, properties: [String: String]) {
        var req = URLRequest(url: plausibleAPIEventURL)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        var jsonObject: [String: Any] = [
            "name": name,
            "url": constructPageviewURL(path: path),
            "domain": domainHost
        ]
        
        if !properties.isEmpty {
            jsonObject["props"] = properties
        }
        
        let jsonData = try? JSONSerialization.data(withJSONObject: jsonObject)
        req.httpBody = jsonData
        
        URLSession.shared.dataTask(with: req) { data, response, err in
            if let err = err {
                var resString = ""
                if let data {
                  resString = String(data: data, encoding: .utf8) ?? ""
                }
                print("error sending pageview to Plausible: \(err): \(resString)")
            }
        }.resume()
    }
    
    internal func constructPageviewURL(path: String) -> String {
        // TODO: replace with iOS 16-only path methods at some point
        return domain.appendingPathComponent(path).absoluteString
    }
}

public enum PlausibleError: Error {
    case invalidServer
    case invalidDomain
    case eventIsPageview
}
