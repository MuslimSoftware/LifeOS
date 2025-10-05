import Foundation

enum ImportError: Error, LocalizedError {
    case noAPIKey
    case imageLoadFailed(URL)
    case pdfLoadFailed(URL)
    case extractionFailed(underlying: Error)
    case noTextFound
    case invalidFileType(String)
    
    var errorDescription: String? {
        switch self {
        case .noAPIKey:
            return "OpenAI API key is required. Please add your API key in Settings."
        case .imageLoadFailed(let url):
            return "Failed to load image from \(url.lastPathComponent)"
        case .pdfLoadFailed(let url):
            return "Failed to load PDF from \(url.lastPathComponent)"
        case .extractionFailed(let error):
            if let urlError = error as? URLError {
                switch urlError.code {
                case .notConnectedToInternet:
                    return "No internet connection. Please check your network and try again."
                case .timedOut:
                    return "Request timed out. Please try again."
                case .cannotFindHost:
                    return "Cannot reach OpenAI servers. Please check your internet connection."
                default:
                    return "Network error: \(urlError.localizedDescription)"
                }
            }
            return "Failed to extract text: \(error.localizedDescription)"
        case .noTextFound:
            return "No text could be extracted from the image. Please ensure the image contains visible text and is in focus."
        case .invalidFileType(let ext):
            return "Unsupported file type: \(ext). Please select PNG, JPEG, HEIC, or PDF files."
        }
    }
}
