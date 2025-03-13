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
                    addSampleWebPagesIfNeeded()
                }
        }
        .modelContainer(sharedModelContainer)
        .onChange(of: scenePhase) { oldPhase, newPhase in
            if newPhase == .background {
                // App is going to background, but we want content to remain loaded
                // We don't clear the cache here to keep webpages loaded
            } else if newPhase == .active {
                // App becomes active
                // Refresh the keepAlive ID to ensure views are properly maintained
                keepAlive = UUID()
            } else if newPhase == .inactive {
                // App is inactive
            }
        }
    }
    
    private func addSampleWebPagesIfNeeded() {
        let context = sharedModelContainer.mainContext
        let fetchDescriptor = FetchDescriptor<WebPage>()
        
        do {
            let existingPages = try context.fetch(fetchDescriptor)
            
            if existingPages.isEmpty {
                // Add sample web pages with proper order values
                let samplePages = [
                    WebPage(url: "https://www.apple.com", title: "Apple", order: 0),
                    WebPage(url: "https://www.google.com", title: "Google", order: 1),
                    WebPage(url: "https://www.github.com", title: "GitHub", order: 2),
                    WebPage(url: "https://www.wikipedia.org", title: "Wikipedia", order: 3),
                    WebPage(url: "https://www.nytimes.com", title: "New York Times", order: 4)
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
