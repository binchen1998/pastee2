//
//  APIService.swift
//  Pastee
//
//  API 网络请求服务
//

import Foundation
import AppKit

class APIService {
    static let shared = APIService()
    
    let baseURL = "https://api.pastee-app.com"
    
    private let session: URLSession
    
    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10
        config.timeoutIntervalForResource = 30
        session = URLSession(configuration: config)
    }
    
    // MARK: - Generic Request
    
    private func createRequest(url: URL, method: String = "GET") -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        if let token = AuthService.shared.getToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        return request
    }
    
    // MARK: - Clipboard Items
    
    func getClipboardItems(page: Int = 1, pageSize: Int = 50, category: String = "all") async throws -> ClipboardListResponse {
        var components = URLComponents(string: "\(baseURL)/clipboard/items")!
        
        // 构建查询参数 (与Windows版本保持一致)
        var queryItems = [
            URLQueryItem(name: "page", value: String(page)),
            URLQueryItem(name: "page_size", value: String(pageSize))
        ]
        
        // 只有非"all"时才传category参数
        if category == "bookmarked" {
            queryItems.append(URLQueryItem(name: "bookmarked_only", value: "true"))
        } else if category != "all" {
            queryItems.append(URLQueryItem(name: "category", value: category))
        }
        // "all" 时不传 category 参数
        
        components.queryItems = queryItems
        
        let request = createRequest(url: components.url!, method: "GET")
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.unknown(-1)
        }
        
        if httpResponse.statusCode == 401 {
            throw APIError.unauthorized
        }
        
        guard httpResponse.statusCode == 200 else {
            throw APIError.unknown(httpResponse.statusCode)
        }
        
        let decoder = JSONDecoder()
        return try decoder.decode(ClipboardListResponse.self, from: data)
    }
    
    func uploadTextItem(content: String, contentType: String, deviceId: String, createdAt: Date) async throws -> ClipboardEntry {
        let url = URL(string: "\(baseURL)/clipboard/items")!
        var request = createRequest(url: url, method: "POST")
        
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        var body = Data()
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let dateString = dateFormatter.string(from: createdAt)
        
        // content_type
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"content_type\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(contentType)\r\n".data(using: .utf8)!)
        
        // content
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"content\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(content)\r\n".data(using: .utf8)!)
        
        // device_id
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"device_id\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(deviceId)\r\n".data(using: .utf8)!)
        
        // created_at
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"created_at\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(dateString)\r\n".data(using: .utf8)!)
        
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = body
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.unknown(-1)
        }
        
        if httpResponse.statusCode == 409 {
            throw APIError.conflict
        }
        
        guard httpResponse.statusCode == 200 || httpResponse.statusCode == 201 else {
            throw APIError.unknown(httpResponse.statusCode)
        }
        
        return try JSONDecoder().decode(ClipboardEntry.self, from: data)
    }
    
    func uploadImageItem(imageData: Data, deviceId: String, createdAt: Date) async throws -> ClipboardEntry {
        let url = URL(string: "\(baseURL)/clipboard/items")!
        var request = createRequest(url: url, method: "POST")
        
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        var body = Data()
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let dateString = dateFormatter.string(from: createdAt)
        
        // content_type
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"content_type\"\r\n\r\n".data(using: .utf8)!)
        body.append("image\r\n".data(using: .utf8)!)
        
        // device_id
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"device_id\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(deviceId)\r\n".data(using: .utf8)!)
        
        // created_at
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"created_at\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(dateString)\r\n".data(using: .utf8)!)
        
        // file
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"image.png\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/png\r\n\r\n".data(using: .utf8)!)
        body.append(imageData)
        body.append("\r\n".data(using: .utf8)!)
        
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = body
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.unknown(-1)
        }
        
        if httpResponse.statusCode == 409 {
            throw APIError.conflict
        }
        
        guard httpResponse.statusCode == 200 || httpResponse.statusCode == 201 else {
            throw APIError.unknown(httpResponse.statusCode)
        }
        
        return try JSONDecoder().decode(ClipboardEntry.self, from: data)
    }
    
    func deleteItem(id: String) async throws {
        let url = URL(string: "\(baseURL)/clipboard/items/\(id)")!
        let request = createRequest(url: url, method: "DELETE")
        
        let (_, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw APIError.unknown((response as? HTTPURLResponse)?.statusCode ?? -1)
        }
    }
    
    func updateItem(id: String, content: String? = nil, isBookmarked: Bool? = nil) async throws -> ClipboardEntry {
        let url = URL(string: "\(baseURL)/clipboard/items/\(id)")!
        var request = createRequest(url: url, method: "PATCH")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        var body: [String: Any] = [:]
        if let content = content { body["content"] = content }
        if let isBookmarked = isBookmarked { body["is_bookmarked"] = isBookmarked }
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw APIError.unknown((response as? HTTPURLResponse)?.statusCode ?? -1)
        }
        
        return try JSONDecoder().decode(ClipboardEntry.self, from: data)
    }
    
    func getOriginalImage(id: String) async throws -> String? {
        let url = URL(string: "\(baseURL)/clipboard/items/\(id)/original")!
        let request = createRequest(url: url, method: "GET")
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw APIError.unknown((response as? HTTPURLResponse)?.statusCode ?? -1)
        }
        
        // API返回JSON格式: { "original_image": "base64..." }
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let originalImage = json["original_image"] as? String {
            return originalImage
        }
        
        return nil
    }
    
    func searchItems(query: String, page: Int = 1, pageSize: Int = 50) async throws -> ClipboardListResponse {
        var components = URLComponents(string: "\(baseURL)/clipboard/items/search")!
        components.queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "page", value: String(page)),
            URLQueryItem(name: "page_size", value: String(pageSize))
        ]
        
        let request = createRequest(url: components.url!, method: "GET")
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw APIError.unknown((response as? HTTPURLResponse)?.statusCode ?? -1)
        }
        
        return try JSONDecoder().decode(ClipboardListResponse.self, from: data)
    }
    
    // MARK: - Categories (端点: /categories, 非 /clipboard/categories)
    
    func getCategories() async throws -> [Category] {
        let url = URL(string: "\(baseURL)/categories")!
        let request = createRequest(url: url, method: "GET")
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            return []
        }
        
        // 404表示端点不存在，返回空数组
        if httpResponse.statusCode == 404 {
            return []
        }
        
        guard httpResponse.statusCode == 200 else {
            throw APIError.unknown(httpResponse.statusCode)
        }
        
        // 尝试解码为数组或对象
        if let categories = try? JSONDecoder().decode([Category].self, from: data) {
            return categories
        }
        
        // 如果是包装在对象中的
        if let wrapper = try? JSONDecoder().decode(CategoriesResponse.self, from: data) {
            return wrapper.categories
        }
        
        return []
    }
    
    func createCategory(name: String) async throws -> Category {
        let url = URL(string: "\(baseURL)/categories")!
        var request = createRequest(url: url, method: "POST")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["name": name])
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 || httpResponse.statusCode == 201 else {
            throw APIError.unknown((response as? HTTPURLResponse)?.statusCode ?? -1)
        }
        
        return try JSONDecoder().decode(Category.self, from: data)
    }
    
    func deleteCategory(id: String) async throws {
        let url = URL(string: "\(baseURL)/categories/\(id)")!
        let request = createRequest(url: url, method: "DELETE")
        
        let (_, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw APIError.unknown((response as? HTTPURLResponse)?.statusCode ?? -1)
        }
    }
    
    func addItemToCategory(categoryId: String, itemId: String) async throws {
        let url = URL(string: "\(baseURL)/categories/\(categoryId)/items/\(itemId)")!
        let request = createRequest(url: url, method: "POST")
        
        let (_, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw APIError.unknown((response as? HTTPURLResponse)?.statusCode ?? -1)
        }
    }
}

// MARK: - API Error

enum APIError: Error {
    case networkError(Error)
    case timeout
    case unauthorized
    case forbidden
    case notFound
    case conflict
    case serverError
    case unknown(Int)
    
    var localizedDescription: String {
        switch self {
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .timeout:
            return "Request timed out. Please check your network connection."
        case .unauthorized:
            return "Session expired. Please login again."
        case .forbidden:
            return "Access denied."
        case .notFound:
            return "Resource not found."
        case .conflict:
            return "Duplicate item."
        case .serverError:
            return "Server error. Please try again later."
        case .unknown(let code):
            return "Unknown error (code: \(code))"
        }
    }
}

