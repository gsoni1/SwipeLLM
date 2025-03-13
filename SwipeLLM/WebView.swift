//
//  WebView.swift
//  SwipeLLM
//
//  Created by Gautam Soni on 3/12/25.
//

import SwiftUI
import WebKit
import Combine

// Cache to store WKWebView instances
class WebViewCache: NSObject {
    static let shared = WebViewCache()
    private var cache = [String: CachedWebView]()
    
    private override init() {
        super.init()
    }
    
    func getWebView(for urlString: String) -> WKWebView {
        if let cachedItem = cache[urlString] {
            return cachedItem.webView
        } else {
            // Create a configuration that enables process pool sharing
            let configuration = WKWebViewConfiguration()
            configuration.processPool = WKProcessPool.shared
            // Disable content compression
            configuration.suppressesIncrementalRendering = false
            // Allow more memory usage
            configuration.websiteDataStore = WKWebsiteDataStore.default()
            
            let webView = WKWebView(frame: .zero, configuration: configuration)
            // Disable jiggling when scrolling at edges
            webView.scrollView.bounces = false
            // Prevent automatic scaling
            webView.scrollView.bouncesZoom = false
            // Ensure content is never purged
            webView.configuration.websiteDataStore.httpCookieStore.add(self)
            
            let cachedItem = CachedWebView(webView: webView)
            cache[urlString] = cachedItem
            return webView
        }
    }
    
    func clearCache() {
        cache.forEach { _, cachedItem in
            cachedItem.webView.stopLoading()
        }
        cache.removeAll()
    }
    
    // Mark a URL as loaded
    func markAsLoaded(urlString: String) {
        if let cachedItem = cache[urlString] {
            cachedItem.isLoaded = true
        }
    }
    
    // Preload a URL in the background
    func preload(urlString: String) {
        guard let url = URL(string: urlString), !cache.keys.contains(urlString) else { return }
        
        // Use main thread for WKWebView creation since it must be created on main thread
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // Create configuration and webview on main thread
            let configuration = WKWebViewConfiguration()
            configuration.processPool = WKProcessPool.shared
            let webView = WKWebView(frame: .zero, configuration: configuration)
            
            // Load the request
            let request = URLRequest(url: url)
            webView.load(request)
            
            // Store in cache
            let cachedItem = CachedWebView(webView: webView)
            self.cache[urlString] = cachedItem
        }
    }
}

// Make WebViewCache conform to WKHTTPCookieStoreObserver to keep cookies
extension WebViewCache: WKHTTPCookieStoreObserver {
    func cookiesDidChange(in cookieStore: WKHTTPCookieStore) {
        // This is needed to conform to the protocol but we don't need to do anything
    }
}

// Extension to share process pool across WebViews
extension WKProcessPool {
    static let shared = WKProcessPool()
}

// Class to hold a cached WebView and its state
class CachedWebView {
    let webView: WKWebView
    var isLoaded = false
    
    init(webView: WKWebView) {
        self.webView = webView
    }
}

struct WebView: UIViewRepresentable {
    let url: URL
    
    // Use this to force the view to stay alive
    @State private var viewID = UUID()
    
    // This is critical - it ensures the view is never recreated
    static func dismantleUIView(_ uiView: WKWebView, coordinator: Coordinator) {
        // Do nothing - this prevents the webview from being destroyed
    }
    
    func makeUIView(context: Context) -> WKWebView {
        let webView = WebViewCache.shared.getWebView(for: url.absoluteString)
        webView.navigationDelegate = context.coordinator
        
        // Only load if not already loaded or if the URL is different
        if webView.url == nil || webView.url?.absoluteString != url.absoluteString {
            let request = URLRequest(url: url, cachePolicy: .returnCacheDataElseLoad)
            webView.load(request)
        }
        
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        // Only reload if URL has changed and is different from current
        if webView.url?.absoluteString != url.absoluteString {
            let request = URLRequest(url: url, cachePolicy: .returnCacheDataElseLoad)
            webView.load(request)
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, WKNavigationDelegate {
        var parent: WebView
        
        init(_ parent: WebView) {
            self.parent = parent
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            // Mark as loaded in cache
            if let urlString = webView.url?.absoluteString {
                WebViewCache.shared.markAsLoaded(urlString: urlString)
            }
        }
        
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            print("WebView navigation failed: \(error.localizedDescription)")
        }
    }
} 
