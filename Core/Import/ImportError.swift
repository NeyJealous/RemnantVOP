import Foundation

enum ProfileImportError: LocalizedError {
    case emptyInput
    case unsupportedFormat
    case invalidURL
    case invalidBase64
    case invalidCompressedData
    case invalidJSON

    var errorDescription: String? {
        switch self {
        case .emptyInput: return "Пустые данные импорта."
        case .unsupportedFormat: return "Формат пока не поддерживается."
        case .invalidURL: return "Некорректная ссылка."
        case .invalidBase64: return "Не удалось декодировать Base64 из vpn://."
        case .invalidCompressedData: return "Не удалось распаковать конфигурацию vpn://."
        case .invalidJSON: return "vpn:// распакован, но внутри нет корректного JSON."
        }
    }
}
