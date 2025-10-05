# Freewrite - AI Coding Agent Guide

> **Quick Reference for AI Assistants**  
> This document provides everything you need to understand, navigate, and contribute to the Freewrite journal app.

---

## 📱 Project Overview

**Freewrite** is a minimalist, distraction-free journaling app for macOS. It emphasizes:
- **Simplicity**: Clean interface, markdown support, focus mode
- **Speed**: Fast entry creation, auto-save, no friction
- **History**: Grouped entries by year/month with collapsible sections
- **Privacy**: Local-first, files stored in ~/Documents/Freewrite

### Tech Stack
- **Language**: Swift
- **Framework**: SwiftUI (native macOS)
- **Target**: macOS 14.0+
- **Architecture**: MVVM with protocol-oriented services

---

## 🗂️ Project Structure

```
freewrite/
├── App/
│   └── AppDelegate.swift              # App lifecycle, delegate
├── Core/
│   ├── Models/
│   │   ├── HumanEntry.swift           # Entry data model (struct)
│   │   ├── AppSettings.swift          # User preferences (@Observable)
│   │   └── Theme.swift                # Theme colors & styles
│   ├── Services/
│   │   ├── FileManagerService.swift   # File I/O, entry persistence
│   │   ├── PDFExportService.swift     # Export entries as PDF
│   │   ├── KeychainService.swift      # Secure credential storage
│   │   ├── OpenAIService.swift        # OCR via OpenAI API
│   │   └── Protocols/
│   │       ├── OCRServiceProtocol.swift
│   │       └── APIKeyStorageProtocol.swift
│   └── Utilities/
│       ├── Constants.swift            # App-wide constants
│       └── Extensions.swift           # Swift extensions
├── Features/
│   ├── Navigation/
│   │   └── SidebarView.swift          # App-wide sidebar navigation
│   ├── Journal/
│   │   └── JournalPageView.swift      # Main journal page container
│   ├── Editor/
│   │   ├── Views/
│   │   │   └── EditorView.swift       # Text editor with placeholder
│   │   └── ViewModels/
│   │       └── EditorViewModel.swift  # Editor state & timer logic
│   ├── EntryList/
│   │   ├── Models/
│   │   │   └── EntryGroup.swift       # Year/month grouping structures
│   │   ├── Views/
│   │   │   ├── EntryListView.swift    # Sidebar entry history
│   │   │   ├── EntryRowView.swift     # Individual entry row
│   │   │   └── SectionHeaderView.swift # Year/month headers
│   │   └── ViewModels/
│   │       └── EntryListViewModel.swift # Entry management logic
│   ├── BottomNavigation/
│   │   ├── Views/
│   │   │   └── BottomNavigationView.swift # Bottom bar container
│   │   └── Components/
│   │       ├── UtilityButtonsView.swift   # New entry, import, etc.
│   │       ├── TimerButtonView.swift      # Focus timer
│   │       └── FontSelectorView.swift     # Font customization
│   ├── Calendar/
│   │   └── CalendarView.swift         # Date picker & entry calendar
│   ├── Import/
│   │   ├── ImportView.swift           # Image/PDF import UI
│   │   ├── ImportViewModel.swift      # Import state management
│   │   ├── ImportService.swift        # Import orchestration
│   │   └── [Supporting files]
│   ├── Settings/
│   │   └── SettingsView.swift         # App preferences UI
│   └── Home/
│       └── HomeView.swift             # Dashboard/summary view
├── ContentView.swift                  # Root view, auto-save logic
└── freewriteApp.swift                 # App entry point
```

---

## 🎯 Core Features

### 1. **Draft Entry Pattern**
**What**: Entries aren't saved until the user types something.

**Why**: Prevents empty entries cluttering history.

**How**:
- On app launch, create draft entry in memory (`EntryListViewModel.draftEntry`)
- Draft is NOT in `entries` array or `groupedEntries`
- On first keystroke, promote draft to saved entry
- Add to `entries`, save to disk, re-group, appear in history

**Key Files**:
- `EntryListViewModel.swift` - `createDraftEntry()`, `promoteDraftToSaved()`
- `ContentView.swift` - Auto-save `onChange` handler

### 2. **Grouped Entry History**
**What**: Entries organized by Year → Month with collapsible sections.

**Why**: Scalable organization for hundreds of entries.

**How**:
- `entries` - Flat array (source of truth)
- `groupedEntries` - Hierarchical structure (for UI)
- SwiftUI `Section` with pinned headers
- Native disclosure triangles for expand/collapse

**Important**: `HumanEntry` is a **struct** (value type). When updating `entries`, always re-group:
```swift
entries[index].previewText = "New text"
groupedEntries = groupEntriesByDate(entries)  // ← REQUIRED!
```

**Key Files**:
- `EntryGroup.swift` - `EntryGroup`, `MonthGroup` structs
- `EntryListViewModel.swift` - `groupEntriesByDate()`, expand/collapse logic
- `EntryListView.swift` - UI with `Section` and `ForEach`

### 3. **Auto-Save**
**What**: Save entry on every text change.

**How**: `ContentView.swift` has `onChange(of: editorVM.text)` that calls `saveEntry()`

**Key Logic**:
```swift
.onChange(of: editorVM.text) {
    if let currentId = entryListVM.selectedEntryId {
        // Check BOTH entries array AND draftEntry
        let currentEntry = entryListVM.entries.first(where: { $0.id == currentId }) 
                        ?? entryListVM.draftEntry
        if let currentEntry = currentEntry {
            entryListVM.saveEntry(entry: currentEntry, content: editorVM.text)
        }
    }
}
```

### 4. **Preview Text Updates**
**What**: Entry titles in sidebar update as you type.

**How**: 
- For short content (< 20 chars): Update from memory (fast)
- For long content (>= 20 chars): Read from disk

**Important**: After updating `entries[index].previewText`, always re-group:
```swift
entries[index].previewText = newPreview
groupedEntries = groupEntriesByDate(entries)  // ← UI sync!
```

**Key Files**:
- `EntryListViewModel.swift` - `updatePreviewTextFromContent()`, `updatePreviewText()`

### 5. **File Storage**
**Location**: `~/Documents/Freewrite/`

**Filename Format**: `[UUID]-[timestamp].md`
- Example: `[A1B2C3...]-[2025-01-15-14-30-00].md`

**File Format**:
```markdown
---
date: Jan 15
year: 2025
---
Entry content goes here...
```

**Key Files**:
- `FileManagerService.swift` - Save/load/delete operations

### 6. **Focus Timer**
**What**: Optional focus timer that auto-hides bottom nav when running.

**Key Files**:
- `EditorViewModel.swift` - Timer state
- `TimerButtonView.swift` - Timer UI

---

## 🏗️ Architecture Patterns

### 1. Protocol-Oriented Programming
Services use protocols for testability and flexibility:

```swift
protocol OCRServiceProtocol {
    func extractText(from image: NSImage) async throws -> ExtractedContent
}

class OpenAIService: OCRServiceProtocol {
    // Implementation
}

// Easy to mock in tests
class MockOCRService: OCRServiceProtocol { /* ... */ }
```

### 2. Dependency Injection
Services injected via initializers with sensible defaults:

```swift
class ImportService {
    private let ocrService: OCRServiceProtocol
    
    init(ocrService: OCRServiceProtocol = OpenAIService()) {
        self.ocrService = ocrService
    }
}
```

### 3. SwiftUI @Observable
Modern observation pattern (iOS 17+/macOS 14+):

```swift
@Observable
class EntryListViewModel {
    var entries: [HumanEntry] = []
    var selectedEntryId: UUID? = nil
}

// In views:
@Environment(EntryListViewModel.self) private var viewModel
```

### 4. Explicit Error Handling
Custom error types with user-friendly messages:

```swift
enum ImportError: Error, LocalizedError {
    case noAPIKey
    case imageLoadFailed(URL)
    
    var errorDescription: String? {
        switch self {
        case .noAPIKey:
            return "OpenAI API key not found. Please add it in Settings."
        case .imageLoadFailed(let url):
            return "Failed to load image: \(url.lastPathComponent)"
        }
    }
}
```

---

## 💡 Common Tasks

### Adding a New Entry to History
```swift
let newEntry = HumanEntry.createNew()
entries.insert(newEntry, at: 0)
groupedEntries = groupEntriesByDate(entries)  // ← Don't forget!
fileService.saveEntry(newEntry, content: text)
```

### Updating Entry Preview Text
```swift
if let index = entries.firstIndex(where: { $0.id == entry.id }) {
    entries[index].previewText = "New preview"
    groupedEntries = groupEntriesByDate(entries)  // ← Required!
}
```

### Deleting an Entry
```swift
try fileService.deleteEntry(entry)
entries.remove(at: index)
groupedEntries = groupEntriesByDate(entries)  // ← Required!
```

### Creating a Draft Entry
```swift
let draft = HumanEntry.createNew()
draftEntry = draft
selectedEntryId = draft.id
// Don't add to entries or groupedEntries yet!
```

### Promoting Draft to Saved
```swift
fileService.saveEntry(draft, content: content)
entries.insert(draft, at: 0)
groupedEntries = groupEntriesByDate(entries)
draftEntry = nil
```

---

## ⚠️ Important Gotchas

### 1. **Struct Value Semantics**
`HumanEntry` is a struct. Copies don't share state:
```swift
// ❌ Wrong - updating copy doesn't update original
var entry = entries[0]
entry.previewText = "New text"  // entries[0] unchanged!

// ✅ Correct - update in place
entries[0].previewText = "New text"
groupedEntries = groupEntriesByDate(entries)  // Re-group!
```

### 2. **Always Re-Group After Mutations**
When you modify `entries` array, the UI reads from `groupedEntries`, so re-group:
```swift
// After ANY of these:
entries.insert(...)
entries.remove(...)
entries[i].previewText = ...
entries[i].date = ...

// Always call:
groupedEntries = groupEntriesByDate(entries)
```

### 3. **Draft Entry Location**
Draft entries are in `draftEntry` property, NOT in `entries` array:
```swift
// ✅ Correct - check both places
let current = entries.first(where: { $0.id == id }) ?? draftEntry

// ❌ Wrong - only checks entries
let current = entries.first(where: { $0.id == id })
```

### 4. **Year Formatting**
Use `Text(verbatim:)` to avoid locale formatting (2025 not 2,025):
```swift
// ❌ Wrong - shows "2,025" in US locale
Text("\(year)")

// ✅ Correct - shows "2025"
Text(verbatim: "\(year)")
```

### 5. **Network Entitlements**
OpenAI API requires network access:
```xml
<!-- freewrite.entitlements -->
<key>com.apple.security.network.client</key>
<true/>
```

---

## 📝 Coding Conventions

### File Organization
- **Group by feature**, not by type (Views/, ViewModels/ together)
- **Services** are global (Core/Services/)
- **Models** used by multiple features go in Core/Models/
- **Feature-specific models** stay in feature folder

### Naming
- **ViewModels**: End with `ViewModel` (e.g., `EditorViewModel`)
- **Services**: End with `Service` (e.g., `FileManagerService`)
- **Views**: Descriptive names (e.g., `EntryRowView`, `SectionHeaderView`)
- **Protocols**: End with `Protocol` (e.g., `OCRServiceProtocol`)

### Comments
- **Avoid redundant comments** - code should be self-documenting
- **Good names > comments**
- Only comment non-obvious WHY, not WHAT

### SwiftUI Style
- Use `@Environment` for dependency injection
- Prefer `.onChange()` over `onAppear` for reactive updates
- Extract complex views into separate components
- Keep view bodies under ~100 lines

---

## 🔍 Where to Find Things

**Need to...**
- **Modify entry saving logic** → `FileManagerService.swift`
- **Change editor behavior** → `EditorViewModel.swift`
- **Update entry list UI** → `EntryListView.swift`
- **Modify grouping logic** → `EntryListViewModel.groupEntriesByDate()`
- **Change auto-save** → `ContentView.swift` `onChange` handler
- **Add new feature** → Create folder in `Features/`
- **Modify theme colors** → `Theme.swift`
- **Update app settings** → `AppSettings.swift`
- **Change entry model** → `HumanEntry.swift`

---

## 🚀 Quick Start for New Features

1. **Create feature folder** in `Features/`
2. **Add View** (if needed)
3. **Add ViewModel** (if needed) with `@Observable`
4. **Add Service** (if business logic) with protocol
5. **Update navigation** to access new feature
6. **Test thoroughly** - draft entries, grouping, auto-save

---

## 🧪 Testing Checklist

When making changes, verify:
- ✅ Draft entries work (not in history until typing)
- ✅ Entry appears in history after typing
- ✅ Preview text updates in sidebar
- ✅ Grouping works (year/month sections)
- ✅ Expand/collapse works
- ✅ Delete removes entry from UI
- ✅ Auto-save works on every keystroke
- ✅ Switching entries saves current one
- ✅ Year displays as "2025" not "2,025"

---

## 📚 Key Learnings

### Why Draft Pattern?
Opening the journal used to create empty files immediately, cluttering history. Draft pattern delays file creation until user actually writes something.

### Why Re-Grouping?
Structs are value types. `groupedEntries` contains copies of entries. After modifying `entries` array, re-grouping syncs the UI with the data.

### Why < 20 Char Threshold?
For short content, users want immediate feedback. Reading from disk is slower than updating from memory. 20 chars is a good balance.

### Why Separate entries and groupedEntries?
- `entries` = source of truth (flat, easy to mutate)
- `groupedEntries` = UI representation (hierarchical, easy to display)

---

## 🎓 For AI Assistants

### When Starting a Task:
1. Read this file first
2. Understand the feature area you're working on
3. Check "Common Gotchas" section
4. Look at similar existing code
5. Follow established patterns

### When Stuck:
- Check "Where to Find Things" section
- Look for similar functionality in codebase
- Remember: structs need re-grouping after mutations
- Draft entries are in `draftEntry`, not `entries`

### When Adding Features:
- Match existing architecture patterns
- Use protocol-oriented approach for services
- Keep views under 100 lines
- Update this file if you add major features

---

**Last Updated**: January 2025  
**Maintained By**: AI Coding Assistants working on Freewrite
