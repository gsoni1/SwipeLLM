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
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
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
                // Add sample web pages
                let samplePages = [
                    WebPage(url: "https://www.apple.com", title: "Apple"),
                    WebPage(url: "https://www.google.com", title: "Google"),
                    WebPage(url: "https://www.github.com", title: "GitHub"),
                    WebPage(url: "https://www.wikipedia.org", title: "Wikipedia"),
                    WebPage(url: "https://www.nytimes.com", title: "New York Times")
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
            }
        } catch {
            print("Failed to check or add sample web pages: \(error)")
        }
    }
}
