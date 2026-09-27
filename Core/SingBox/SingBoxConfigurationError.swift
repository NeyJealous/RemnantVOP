import Foundation

enum SingBoxConfigurationError: LocalizedError {
    case invalidShareLink
    case missingHost
    case missingPort
    case missingCredential
    case unsupportedVLESSTransport(String)
    case unsupportedSecurity(String)
    case serializationFailed

    var errorDescription: String? {
        switch self {
        case .invalidShareLink:
            return "Некорректная ссылка профиля."
        case .missingHost:
            return "В ссылке отсутствует адрес сервера."
        case .missingPort:
            return "В ссылке отсутствует порт сервера."
        case .missingCredential:
            return "В ссылке отсутствуют UUID или пароль."
        case .unsupportedVLESSTransport(let value):
            return "VLESS transport \(value) пока не поддерживается текущим sing-box."
        case .unsupportedSecurity(let value):
            return "Режим защиты \(value) пока не поддерживается."
        case .serializationFailed:
            return "Не удалось сформировать конфигурацию sing-box."
        }
    }
}
