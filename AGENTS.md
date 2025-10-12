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
│   │   ├── TODOItem.swift             # TODO item model with optional dueTime
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
│   │   ├── CalendarView.swift         # Date picker & entry calendar
│   │   ├── TODOListView.swift         # TODO list UI with TimePickerView
│   │   └── TODOViewModel.swift        # TODO state management
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
## TODOs
- [ ] Buy groceries @3:30 PM
- [x] Complete project report

## Journal
Entry content goes here...
```

**How File Editing Works**:
- Files have three distinct sections: metadata (YAML frontmatter), TODOs, and Journal
- `extractTODOSection()` extracts content between `## TODOs` and `## Journal`
- `extractJournalSection()` extracts everything after `## Journal\n`
- When saving, always preserve the TODO section from disk to prevent overwrites
- Journal content is updated from the editor, TODOs are managed separately

**Key Files**:
- `FileManagerService.swift` - Save/load/delete operations, TODO parsing/saving

### 6. **TODO Management**
**What**: Per-entry TODO lists with optional due times, inline editing, and calendar indicators.

**Storage**:
- TODOs stored in `## TODOs` section of markdown files
- Format: `- [ ] Task text @3:30 PM` or `- [x] Completed task`
- Time is parsed and stored separately in `dueTime: Date?` property
- `parseTODOs()` and `saveTODOs()` handle conversion between disk format and in-memory model

**TODO-Only Files**:
- Files can exist with TODOs but no journal content (empty `## Journal` section)
- These files are automatically created when adding TODOs to a date without a journal entry
- TODO-only files are excluded from journal history (`loadExistingEntries` filters them out)
- `loadTODOsForDate(date:)` finds TODOs for any date, including from TODO-only files
- `findExistingFileForDate(date:)` checks if any file exists for a date
- When creating a journal entry for a date with a TODO-only file, it's converted to a regular entry

**UI Features**:
- Click TODO text to edit inline (TextField replaces Text)
- Save on Enter/focus-loss, cancel on Escape
- Scroll-based time picker with debounced saves (0.5s delay, threshold: 3)
- Global scroll monitor in TODOListView parent prevents UI blocking
- Completed TODOs are read-only (no text/time editing, dimmed color only)
- Delete button appears on hover

**Calendar Integration**:
- Day cells show TODO indicators (3rd row below journal dot)
- Empty circles (○) for incomplete, filled (●) for completed (max 3 visible)
- Indicators shown for both regular entries and TODO-only files
- Auto-updates via `@Observable` pattern when TODOs change
- Cached in `todoCounts: [String: (incomplete, completed)]` for performance
- `refreshTODOCounts()` uses `loadTODOsForDate()` to include TODO-only files

**Key Files**:
- `TODOItem.swift` - Data model (Identifiable, Codable, Equatable) with `dueTime: Date?`
- `TODOViewModel.swift` - State management, CRUD operations, auto-creates entry on first TODO
- `TODOListView.swift` - Main list, row view with inline editing, time picker with scroll handling
- `CalendarView.swift` - Calendar grid with TODO indicators, journal/TODO side-by-side view
- `FileManagerService.swift` - Disk I/O, `loadTODOsForDate()`, `findExistingFileForDate()`

### 7. **Calendar Page**
**What**: Monthly calendar view showing entries and TODOs with side-by-side journal/TODO interface.

**Layout**:
- Top: Month name and calendar grid (6x7 or 5x7 depending on month)
- Bottom: Split view with Journal section (left) and TODO section (right)
- Footer: Month/Year navigation and "Today" button

**Journal Section**:
- Always visible when a day is selected
- Shows list of journal entries if they exist
- Shows "+" button if no journal entry exists for the date
- Clicking "+" creates entry and navigates to journal page
- Handles conversion of TODO-only files to regular entries

**TODO Section**:
- Always visible when a day is selected
- Shows TODOs for the selected date (from entry or TODO-only file)
- Allows adding TODOs to any date without creating journal entry
- Auto-creates TODO-only file on first TODO if no entry exists

**Day Cell Indicators**:
- Blue dot: Journal entry exists
- Empty circles (○): Incomplete TODOs
- Filled circles (●): Completed TODOs
- Max 3 TODO indicators shown per day

**Key Methods**:
- `createJournalForSelectedDay()` - Creates entry or converts TODO-only file
- `updateTODOsForSelectedDay()` - Loads TODOs including from TODO-only files
- `refreshTODOCounts()` - Updates indicators for all days in month
- `entriesForSelectedDay()` - Filters entries by date

**Key Files**:
- `CalendarView.swift` - Main calendar UI and logic
- `TODOListView.swift` - TODO interface component
- `TODOViewModel.swift` - TODO state with date tracking

### 8. **Focus Timer**
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

### Adding a TODO
```swift
let newTODO = TODOItem(text: "Buy groceries", completed: false)
todos.append(newTODO)
fileService.saveTODOs(todos, for: entry)
```

### Updating TODO Time
```swift
// Create new instance with updated dueTime
let calendar = Calendar.current
var components = DateComponents()
components.hour = 15  // 3 PM in 24-hour
components.minute = 30
let newTime = calendar.date(from: components)

todos[index] = TODOItem(
    id: todos[index].id,
    text: todos[index].text,
    completed: todos[index].completed,
    createdAt: todos[index].createdAt,
    dueTime: newTime
)
fileService.saveTODOs(todos, for: entry)
```

### Loading TODOs for Entry
```swift
let todos = fileService.loadTODOs(for: entry)
// Returns [TODOItem] with parsed text and dueTime
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

### 6. **TODO Section Preservation**
When saving journal content, always preserve the TODO section:
```swift
// ❌ Wrong - overwrites entire file, loses TODOs
try content.write(to: fileURL, atomically: true, encoding: .utf8)

// ✅ Correct - load existing TODOs first
let existingContent = try? String(contentsOf: fileURL, encoding: .utf8)
let todoSection = existingContent != nil ? extractTODOSection(from: existingContent!) : ""
// Then reconstruct with metadata + todoSection + journal
```

### 7. **TODO Time Format**
Time is stored in markdown as `@H:MM AM/PM`, but stripped from text in TODOItem:
```swift
// In file: - [ ] Buy groceries @3:30 PM
// TODOItem.text: "Buy groceries"  (no time)
// TODOItem.dueTime: Date(hour: 15, minute: 30)  (24-hour format)

// When saving, time is reconstructed and appended
```

### 8. **TODOItem is a Struct**
Like HumanEntry, TODOItem is a struct. When updating, create new instance:
```swift
// ❌ Wrong - can't mutate struct copy
var todo = todos[0]
todo.completed = true  // todos[0] unchanged!

// ✅ Correct - replace with new instance
todos[index] = TODOItem(
    id: todos[index].id,
    text: todos[index].text,
    completed: !todos[index].completed,
    createdAt: todos[index].createdAt,
    dueTime: todos[index].dueTime
)
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
- **Add/modify TODOs** → `TODOViewModel.swift`, `TODOListView.swift`
- **Change TODO parsing/saving** → `FileManagerService.swift` (`parseTODOs`, `saveTODOs`)
- **Handle TODO-only files** → `FileManagerService.swift` (`loadTODOsForDate`, `findExistingFileForDate`)
- **Update calendar/TODO UI** → `CalendarView.swift`
- **Calendar journal creation** → `CalendarView.createJournalForSelectedDay()`
- **Add new feature** → Create folder in `Features/`
- **Modify theme colors** → `Theme.swift`
- **Update app settings** → `AppSettings.swift`
- **Change entry model** → `HumanEntry.swift`
- **Change TODO model** → `TODOItem.swift`

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
