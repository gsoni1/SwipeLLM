//
//  ContentView.swift
//  SwipeLLM
//
//  Created by Gautam Soni on 3/12/25.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @Query(sort: \WebPage.order) private var webPages: [WebPage]
    
    // Store the current page index in UserDefaults
    @AppStorage("lastViewedPageIndex") private var lastViewedPageIndex = 0
    @State private var currentPageIndex = 0
    
    @State private var showAddPageSheet = false
    @State private var showSettingsSheet = false
    @State private var newPageURL = ""
    @State private var newPageTitle = ""
    @State private var isDarkMode = false
    @State private var isEditMode = false
    
    // This forces views to stay in memory
    @State private var viewsKeepAlive = UUID()
    
    // Detect when we've reached the end of the list
    @State private var hasReachedEnd = false
    @State private var hasReachedStart = false
    
    var body: some View {
        ZStack {
            // Main content
            VStack {
                if webPages.isEmpty {
                    // Empty state
                    VStack {
                        Spacer()
                        Image(systemName: "globe")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                            .padding()
                        
                        Text("No webpages added yet")
                            .font(.title2)
                            .padding()
                        
                        Button("Add Your First Webpage") {
                            showAddPageSheet = true
                        }
                        .buttonStyle(.borderedProminent)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    // Use a ZStack to force views to stay in memory
                    ZStack {
                        // Swipeable web view container
                        TabView(selection: $currentPageIndex) {
                            // Add a "phantom" view at the beginning to detect swipe to beginning
                            if webPages.count > 0 {
                                Color.clear
                                    .tag(-1)
                                    .onAppear {
                                        hasReachedStart = true
                                        // If we swiped to the phantom view, go back to first real page
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                            if currentPageIndex == -1 {
                                                currentPageIndex = 0
                                                showAddPageSheet = true
                                            }
                                        }
                                    }
                            }
                            
                            // Regular web pages
                            ForEach(Array(webPages.enumerated()), id: \.element.id) { index, page in
                                WebPageContainer(page: page)
                                    .tag(index)
                                    // This is critical - it prevents SwiftUI from recycling views
                                    .id("page-\(page.id)-\(viewsKeepAlive)")
                                    // Preload the view and keep it in memory
                                    .onAppear {
                                        // Preload adjacent pages for smoother swiping
                                        preloadAdjacentPages(currentIndex: index)
                                        hasReachedEnd = false
                                        hasReachedStart = false
                                    }
                            }
                            
                            // Add a "phantom" view at the end to detect swipe to end
                            if webPages.count > 0 {
                                Color.clear
                                    .tag(webPages.count)
                                    .onAppear {
                                        hasReachedEnd = true
                                        // If we swiped to the phantom view, trigger add page
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                            if currentPageIndex == webPages.count {
                                                currentPageIndex = webPages.count - 1
                                                showAddPageSheet = true
                                            }
                                        }
                                    }
                            }
                        }
                        .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                        // Disable default animations which can cause view recycling
                        .animation(.none, value: currentPageIndex)
                        // Save the current page index whenever it changes
                        .onChange(of: currentPageIndex) { oldValue, newValue in
                            if newValue >= 0 && newValue < webPages.count {
                                lastViewedPageIndex = newValue
                            }
                        }
                    }
                    .id("tabview-container-\(viewsKeepAlive)")
                    
                    // Page indicator and controls
                    VStack(spacing: 0) {
                        // Empty space where controls used to be
                        Spacer()
                            .frame(height: 8)
                        
                        // Combined controls and page indicator
                        HStack {
                            // Settings button on the left
                            Button(action: {
                                showSettingsSheet = true
                            }) {
                                Image(systemName: "gear")
                                    .font(.system(size: 18))
                                    .padding(8)
                                    .background(Color.black.opacity(0.5))
                                    .foregroundColor(.white)
                                    .clipShape(Circle())
                            }
                            .padding(.leading)
                            
                            Spacer()
                            
                            // Page indicator in the center
                            PageIndicatorView(numberOfPages: webPages.count, currentPage: $currentPageIndex)
                            
                            Spacer()
                            
                            // Page count on the right
                            Text("\(currentPageIndex + 1) of \(webPages.count)")
                                .font(.caption)
                                .padding(8)
                                .background(Color.black.opacity(0.5))
                                .foregroundColor(.white)
                                .clipShape(Capsule())
                                .padding(.trailing)
                        }
                        .padding(.bottom, 8)
                    }
                }
            }
        }
        .sheet(isPresented: $showAddPageSheet) {
            AddWebPageView(
                isPresented: $showAddPageSheet,
                url: $newPageURL,
                title: $newPageTitle,
                onAdd: addWebPage
            )
        }
        .sheet(isPresented: $showSettingsSheet) {
            SettingsView(
                webPages: webPages,
                currentIndex: $currentPageIndex,
                isDarkMode: $isDarkMode,
                isPresented: $showSettingsSheet,
                modelContext: modelContext
            )
        }
        // This is important - it refreshes the view hierarchy when the app becomes active
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            viewsKeepAlive = UUID()
        }
        .preferredColorScheme(isDarkMode ? .dark : .light)
        // Restore the last viewed page when the view appears
        .onAppear {
            // Ensure the saved index is valid for the current number of pages
            if !webPages.isEmpty && lastViewedPageIndex >= 0 && lastViewedPageIndex < webPages.count {
                currentPageIndex = lastViewedPageIndex
            } else {
                // Reset to 0 if the saved index is invalid
                currentPageIndex = 0
                lastViewedPageIndex = 0
            }
        }
    }
    
    private func addWebPage() {
        // Don't add if URL is empty or just the https:// prefix
        guard !newPageURL.isEmpty && newPageURL != "https://" else { return }
        
        // Format URL if needed
        if !newPageURL.hasPrefix("http://") && !newPageURL.hasPrefix("https://") {
            newPageURL = "https://" + newPageURL
        }
        
        // Remove any trailing slashes for consistency
        while newPageURL.hasSuffix("/") && newPageURL != "https://" {
            newPageURL.removeLast()
        }
        
        // Auto-generate title from URL if empty
        if newPageTitle.isEmpty {
            if let host = URL(string: newPageURL)?.host {
                newPageTitle = host.replacingOccurrences(of: "www.", with: "")
            } else {
                newPageTitle = "Webpage"
            }
        }
        
        withAnimation {
            // Set the order to be the highest current order + 1
            let newOrder = webPages.isEmpty ? 0 : (webPages.map { $0.order }.max() ?? 0) + 1
            
            let newPage = WebPage(url: newPageURL, title: newPageTitle, order: newOrder)
            modelContext.insert(newPage)
            
            // Reset form fields
            newPageURL = ""
            newPageTitle = ""
            
            // Navigate to the new page
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                currentPageIndex = webPages.count - 1
            }
        }
    }
    
    private func preloadAdjacentPages(currentIndex: Int) {
        // Preload the next and previous pages if they exist
        if currentIndex < webPages.count - 1 {
            let nextPage = webPages[currentIndex + 1]
            let urlString = nextPage.url
            if !urlString.isEmpty, URL(string: urlString) != nil {
                WebViewCache.shared.preload(urlString: urlString)
            }
        }
        
        if currentIndex > 0 {
            let prevPage = webPages[currentIndex - 1]
            let urlString = prevPage.url
            if !urlString.isEmpty, URL(string: urlString) != nil {
                WebViewCache.shared.preload(urlString: urlString)
            }
        }
    }
}

// Settings view for managing pages and app preferences
struct SettingsView: View {
    let webPages: [WebPage]
    @Binding var currentIndex: Int
    @Binding var isDarkMode: Bool
    @Binding var isPresented: Bool
    let modelContext: ModelContext
    @State private var editMode: EditMode = .inactive
    
    var body: some View {
        NavigationView {
            VStack {
                List {
                    Section(header: Text("Appearance")) {
                        Toggle("Dark Mode", isOn: $isDarkMode)
                    }
                    
                    Section(header: Text("Webpages")) {
                        ForEach(webPages) { page in
                            HStack {
                                // Display URL as the primary identifier
                                if let host = URL(string: page.url)?.host {
                                    Text(host.replacingOccurrences(of: "www.", with: ""))
                                        .font(.headline)
                                } else {
                                    Text(page.url)
                                        .font(.headline)
                                }
                                
                                Spacer()
                                
                                if editMode == .active {
                                    Button(action: {
                                        deletePage(page)
                                    }) {
                                        Image(systemName: "trash")
                                            .foregroundColor(.red)
                                    }
                                }
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                if editMode == .inactive {
                                    // Find the index of the tapped page
                                    if let index = webPages.firstIndex(where: { $0.id == page.id }) {
                                        currentIndex = index
                                        isPresented = false
                                    }
                                }
                            }
                        }
                        .onDelete(perform: deletePages)
                        .onMove(perform: movePages)
                    }
                }
                
                Spacer()
                
                // Attribution at the bottom with headline font
                HStack {
                    Text("SwipeLLM - By")
                        .font(.headline)
                    Link("Gautam Soni", destination: URL(string: "https://www.linkedin.com/in/gsoni16/")!)
                        .font(.headline)
                }
                .padding(.bottom, 16)
            }
            .navigationTitle("Settings")
            .navigationBarItems(
                leading: EditButton(),
                trailing: Button("Done") {
                    isPresented = false
                }
            )
            .environment(\.editMode, $editMode)
        }
    }
    
    private func deletePage(_ page: WebPage) {
        modelContext.delete(page)
        
        // Adjust current index if needed
        if currentIndex >= webPages.count - 1 && currentIndex > 0 {
            currentIndex -= 1
        }
    }
    
    private func deletePages(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(webPages[index])
        }
        
        // Adjust current index if needed
        if currentIndex >= webPages.count && currentIndex > 0 {
            currentIndex = webPages.count - 1
        }
    }
    
    private func movePages(from source: IndexSet, to destination: Int) {
        // Convert to array for easier manipulation
        var pagesArray = webPages.map { $0 }
        
        // Perform the move
        pagesArray.move(fromOffsets: source, toOffset: destination)
        
        // Update the order property for each page
        for (index, page) in pagesArray.enumerated() {
            page.order = index
            print("Setting order \(index) for page: \(page.title)")
        }
        
        // Save changes
        do {
            try modelContext.save()
            print("Successfully saved new page orders")
            
            // Verify the save
            let descriptor = FetchDescriptor<WebPage>(sortBy: [SortDescriptor(\WebPage.order)])
            if let verifiedPages = try? modelContext.fetch(descriptor) {
                print("Verified page orders:")
                for page in verifiedPages {
                    print("\(page.title): order \(page.order)")
                }
            }
        } catch {
            print("Failed to save reordering: \(error)")
            // Try to recover by saving again after a short delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                do {
                    try modelContext.save()
                    print("Successfully saved page orders on retry")
                } catch {
                    print("Failed to save on retry: \(error)")
                }
            }
        }
        
        // Update current index if needed
        if let firstSource = source.first, currentIndex == firstSource {
            // If the moved page was the current one, update the index
            let newIndex = firstSource < destination ? destination - 1 : destination
            currentIndex = newIndex
        }
    }
}

// This container ensures the WebPageView stays in memory
struct WebPageContainer: View {
    let page: WebPage
    
    var body: some View {
        WebPageView(page: page)
            // Force this view to stay in memory
            .layoutPriority(1)
    }
}

struct WebPageView: View {
    let page: WebPage
    
    // Use this to uniquely identify each view
    // This is now a constant to ensure the view is never recreated
    private let viewID = UUID()
    
    var body: some View {
        // Use a Group to wrap the conditional content
        Group {
            if let url = URL(string: page.url) {
                // Wrap in a ZStack to force the view to stay in memory
                ZStack {
                    WebView(url: url)
                }
                // Use a constant ID to ensure the view is never recreated
                .id("webview-\(page.id)-\(viewID)")
            } else {
                Text("Invalid URL: \(page.url)")
                    .foregroundColor(.red)
                    .padding()
            }
        }
        // This is critical - it forces SwiftUI to keep this view in memory
        .layoutPriority(1)
    }
}

struct AddWebPageView: View {
    @Binding var isPresented: Bool
    @Binding var url: String
    @Binding var title: String
    var onAdd: () -> Void
    
    // State to track if we've already prefixed the URL
    @State private var hasAddedPrefix = false
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Enter Website URL")) {
                    TextField("example.com", text: $url)
                        .keyboardType(.URL)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                        .onAppear {
                            // Auto-populate title based on domain
                            if title.isEmpty {
                                title = "Webpage"
                            }
                            
                            // Add https:// prefix if not already present
                            if !hasAddedPrefix && !url.isEmpty && !url.hasPrefix("http://") && !url.hasPrefix("https://") {
                                url = "https://" + url
                                hasAddedPrefix = true
                            } else if !hasAddedPrefix && url.isEmpty {
                                url = "https://"
                                hasAddedPrefix = true
                            }
                        }
                        .onChange(of: url) { oldValue, newValue in
                            // If user deletes the entire URL including https://, add it back
                            if newValue.isEmpty {
                                DispatchQueue.main.async {
                                    url = "https://"
                                }
                            }
                            // If user pastes a URL without http/https, add the prefix
                            else if !newValue.hasPrefix("http://") && !newValue.hasPrefix("https://") && !oldValue.isEmpty {
                                DispatchQueue.main.async {
                                    url = "https://" + newValue
                                }
                            }
                        }
                }
                
                Section {
                    Button("Add Webpage") {
                        // Format URL if needed
                        formatURL()
                        
                        // Auto-generate title from URL if empty
                        if title.isEmpty {
                            if let host = URL(string: url)?.host {
                                title = host.replacingOccurrences(of: "www.", with: "")
                            } else {
                                title = "Webpage"
                            }
                        }
                        onAdd()
                        isPresented = false
                    }
                    .disabled(url == "https://" || url.isEmpty)
                    .frame(maxWidth: .infinity, alignment: .center)
                }
            }
            .navigationTitle("Add New Webpage")
            .navigationBarItems(
                trailing: Button("Cancel") {
                    isPresented = false
                }
            )
        }
    }
    
    // Helper function to ensure URL is properly formatted
    private func formatURL() {
        // If URL doesn't have a scheme, add https://
        if !url.hasPrefix("http://") && !url.hasPrefix("https://") {
            url = "https://" + url
        }
        
        // Remove any trailing slashes for consistency
        while url.hasSuffix("/") && url != "https://" {
            url.removeLast()
        }
    }
}

// Add this new view struct after the AddWebPageView
struct PageIndicatorView: View {
    let numberOfPages: Int
    @Binding var currentPage: Int
    @GestureState private var dragOffset: CGFloat = 0
    
    private let maxVisibleDots = 6
    
    private var visibleRange: Range<Int> {
        if numberOfPages <= maxVisibleDots {
            return 0..<numberOfPages
        }
        
        let halfVisible = maxVisibleDots / 2
        var start = currentPage - halfVisible + 1
        var end = start + maxVisibleDots
        
        // Adjust for edges
        if start < 0 {
            start = 0
            end = maxVisibleDots
        } else if end > numberOfPages {
            end = numberOfPages
            start = end - maxVisibleDots
        }
        
        return start..<end
    }
    
    private func dotSize(for index: Int) -> CGFloat {
        if currentPage == index {
            return 10 // Current page dot size
        }
        
        // Calculate distance from current page
        let distance = abs(index - currentPage)
        
        // Size decreases based on distance from current page
        switch distance {
        case 0:
            return 10 // Current page
        case 1:
            return 8 // Adjacent to current
        case 2:
            return 6 // Two away
        default:
            return 4 // Three or more away
        }
    }
    
    private func dotOpacity(for index: Int) -> Double {
        if currentPage == index {
            return 1.0
        }
        
        // Calculate distance from current page
        let distance = abs(index - currentPage)
        
        // Opacity decreases based on distance from current page
        switch distance {
        case 0:
            return 1.0 // Current page
        case 1:
            return 0.7 // Adjacent to current
        case 2:
            return 0.5 // Two away
        default:
            return 0.3 // Three or more away
        }
    }
    
    var body: some View {
        HStack(spacing: 6) {
            ForEach(Array(visibleRange), id: \.self) { index in
                Circle()
                    .fill(Color.white)
                    .opacity(dotOpacity(for: index))
                    .frame(width: dotSize(for: index), height: dotSize(for: index))
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.5), lineWidth: 1)
                    )
                    .onTapGesture {
                        withAnimation {
                            currentPage = index
                        }
                    }
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 16)
        .background(
            Capsule()
                .fill(Color.black.opacity(0.5))
        )
        .gesture(
            DragGesture()
                .updating($dragOffset) { value, state, _ in
                    state = value.translation.width
                }
                .onEnded { value in
                    let threshold: CGFloat = 50
                    if value.translation.width > threshold && currentPage > 0 {
                        withAnimation {
                            currentPage -= 1
                        }
                    } else if value.translation.width < -threshold && currentPage < numberOfPages - 1 {
                        withAnimation {
                            currentPage += 1
                        }
                    }
                }
        )
    }
}

#Preview {
    ContentView()
        .modelContainer(for: WebPage.self, inMemory: true)
}
