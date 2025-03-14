//
//  SwipeLLMApp.swift
//  SwipeLLM
//
//  Created by Gautam Soni on 3/12/25.
//

import SwiftUI
import SwiftData


@main
struct SwipeLLMApp: App {
    // Add a flag to force reset of database
    @AppStorage("shouldResetDatabase") private var shouldResetDatabase = false
    
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            WebPage.self,
        ])
        
        // Create model configuration with migration settings
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            allowsSave: true
        )

        do {
            // Try to create the container with the configuration
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            print("Failed to create ModelContainer: \(error)")
            
            // If creation fails, try to recreate the database
            print("Attempting to recreate the database...")
            
            // Try to delete the existing store
            let storeURL = URL.applicationSupportDirectory.appending(path: "default.store")
            do {
                try FileManager.default.removeItem(at: storeURL)
                print("Deleted existing database at \(storeURL)")
            } catch {
                print("Failed to delete existing database: \(error)")
            }
            
            // Try again with a fresh configuration
            do {
                return try ModelContainer(for: schema, configurations: [modelConfiguration])
            } catch {
                fatalError("Could not create or recreate ModelContainer: \(error)")
            }
        }
    }()
    
    // App lifecycle
    @Environment(\.scenePhase) private var scenePhase
    
    // State to force views to stay loaded
    @State private var keepAlive = UUID()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .id(keepAlive) // Force the view hierarchy to stay alive
                .onAppear {
                    if shouldResetDatabase {
                        resetDatabase()
                        shouldResetDatabase = false
                    } else {
                        addSampleWebPagesIfNeeded()
                    }
                }
        }
        .modelContainer(sharedModelContainer)
        .onChange(of: scenePhase) { oldPhase, newPhase in
            if newPhase == .background {
                // App is going to background
                // Do not clear the cache or destroy WebViews
                print("App entering background - preserving WebView state")
            } else if newPhase == .active {
                // App becomes active
                print("App becoming active - restoring WebView state")
                // Refresh the keepAlive ID to ensure views are properly maintained
                keepAlive = UUID()
                
                // Ensure all pages are in the cache
                Task {
                    let context = sharedModelContainer.mainContext
                    let descriptor = FetchDescriptor<WebPage>(sortBy: [SortDescriptor(\WebPage.order)])
                    if let pages = try? context.fetch(descriptor) {
                        for page in pages {
                            if !page.url.isEmpty, let url = URL(string: page.url) {
                                WebViewCache.shared.preload(urlString: page.url)
                            }
                        }
                    }
                }
            } else if newPhase == .inactive {
                // App is inactive
            }
        }
    }
    
    // Function to reset the database and add new default pages
    private func resetDatabase() {
        let context = sharedModelContainer.mainContext
        
        do {
            // Delete all existing pages
            let fetchDescriptor = FetchDescriptor<WebPage>()
            let existingPages = try context.fetch(fetchDescriptor)
            
            for page in existingPages {
                context.delete(page)
            }
            
            try context.save()
            print("Deleted all existing pages")
            
            // Add new default pages
            let samplePages = [
                WebPage(url: "https://chatgpt.com", title: "ChatGPT", order: 0),
                WebPage(url: "https://notebooklm.google", title: "Google NotebookLM", order: 1),
                WebPage(url: "https://claude.ai", title: "Claude", order: 2),
                WebPage(url: "https://perplexity.ai", title: "Perplexity", order: 3),
                WebPage(url: "https://gemini.google.com/app", title: "Google Gemini", order: 4),
                WebPage(url: "http://chat.deepseek.com", title: "DeepSeek", order: 5),
                WebPage(url: "https://copilot.microsoft.com", title: "Microsoft Copilot", order: 6)
            ]
            
            for page in samplePages {
                context.insert(page)
            }
            
            try context.save()
            print("Added new default pages")
            
            // Preload all sample pages
            for page in samplePages {
                if !page.url.isEmpty, let url = URL(string: page.url) {
                    WebViewCache.shared.preload(urlString: page.url)
                }
            }
        } catch {
            print("Failed to reset database: \(error)")
        }
    }
    
    private func addSampleWebPagesIfNeeded() {
        let context = sharedModelContainer.mainContext
        let fetchDescriptor = FetchDescriptor<WebPage>()
        
        do {
            let existingPages = try context.fetch(fetchDescriptor)
            
            if existingPages.isEmpty {
                // Add AI assistant websites as default pages with proper order values
                let samplePages = [
                    WebPage(url: "https://chatgpt.com", title: "ChatGPT", order: 0),
                    WebPage(url: "https://notebooklm.google", title: "Google NotebookLM", order: 1),
                    WebPage(url: "https://claude.ai", title: "Claude", order: 2),
                    WebPage(url: "https://perplexity.ai", title: "Perplexity", order: 3),
                    WebPage(url: "https://gemini.google.com/app", title: "Google Gemini", order: 4),
                    WebPage(url: "http://chat.deepseek.com", title: "DeepSeek", order: 5),
                    WebPage(url: "https://copilot.microsoft.com", title: "Microsoft Copilot", order: 6)
                ]
                
                for page in samplePages {
                    context.insert(page)
                }
                
                try context.save()
                
                // Preload all sample pages
                for page in samplePages {
                    if !page.url.isEmpty, let url = URL(string: page.url) {
                        WebViewCache.shared.preload(urlString: page.url)
                    }
                }
            } else {
                // Check if we need to update existing pages to add order
                var needsOrderUpdate = false
                for (index, page) in existingPages.enumerated() {
                    if page.order == 0 && index > 0 {
                        // If this isn't the first page but has order 0, we need to update
                        needsOrderUpdate = true
                        break
                    }
                }
                
                // Update orders if needed
                if needsOrderUpdate {
                    for (index, page) in existingPages.enumerated() {
                        page.order = index
                    }
                    try context.save()
                }
            }
        } catch {
            print("Failed to check or add sample web pages: \(error)")
        }
    }
}
