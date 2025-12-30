//
//  ClipboardEntry.swift
//  Pastee
//
//  剪贴板项目数据模型
//

import Foundation

struct ClipboardEntry: Codable, Identifiable, Equatable {
    var id: String
    var contentType: String  // "text", "url", "image"
    var content: String?
    var filePath: String?
    var fileName: String?
    var thumbnail: String?  // Base64 编码的缩略图
    var originalDeleted: Bool?
    var createdAt: Date
    var isBookmarked: Bool
    
    // 本地状态 (不序列化)
    var isUploading: Bool = false
    var uploadFailed: Bool = false
    var displayImageData: String?  // Base64图片数据
    var isThumbnail: Bool = true
    
    enum CodingKeys: String, CodingKey {
        case id
        case contentType = "content_type"
        case content
        case filePath = "file_path"
        case fileName = "file_name"
        case thumbnail
        case originalDeleted = "original_deleted"
        case createdAt = "created_at"
        case isBookmarked = "is_bookmarked"
        case uploadFailed = "upload_failed"
    }
    
    init(id: String = UUID().uuidString,
         contentType: String = "text",
         content: String? = nil,
         filePath: String? = nil,
         fileName: String? = nil,
         thumbnail: String? = nil,
         originalDeleted: Bool? = nil,
         createdAt: Date = Date(),
         isBookmarked: Bool = false,
         isUploading: Bool = false) {
        self.id = id
        self.contentType = contentType
        self.content = content
        self.filePath = filePath
        self.fileName = fileName
        self.thumbnail = thumbnail
        self.originalDeleted = originalDeleted
        self.createdAt = createdAt
        self.isBookmarked = isBookmarked
        self.isUploading = isUploading
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // ID可能是数字或字符串
        if let intId = try? container.decode(Int.self, forKey: .id) {
            id = String(intId)
        } else {
            id = try container.decode(String.self, forKey: .id)
        }
        
        contentType = try container.decode(String.self, forKey: .contentType)
        content = try container.decodeIfPresent(String.self, forKey: .content)
        filePath = try container.decodeIfPresent(String.self, forKey: .filePath)
        fileName = try container.decodeIfPresent(String.self, forKey: .fileName)
        thumbnail = try container.decodeIfPresent(String.self, forKey: .thumbnail)
        originalDeleted = try container.decodeIfPresent(Bool.self, forKey: .originalDeleted)
        
        // 解析日期
        if let dateString = try? container.decode(String.self, forKey: .createdAt) {
            createdAt = ISO8601DateFormatter().date(from: dateString) ?? Date()
        } else {
            createdAt = Date()
        }
        
        // isBookmarked可能是字符串或布尔值
        if let boolValue = try? container.decode(Bool.self, forKey: .isBookmarked) {
            isBookmarked = boolValue
        } else if let stringValue = try? container.decode(String.self, forKey: .isBookmarked) {
            isBookmarked = stringValue.lowercased() == "true" || stringValue == "1"
        } else {
            isBookmarked = false
        }
        
        uploadFailed = try container.decodeIfPresent(Bool.self, forKey: .uploadFailed) ?? false
    }
    
    mutating func initializeImageState() {
        guard contentType == "image" else { return }
        
        // 1. 优先使用content中的base64数据
        if let content = content, isBase64Like(content) {
            displayImageData = content
            isThumbnail = true
        }
        // 2. 备选：Thumbnail字段
        else if let thumbnail = thumbnail {
            displayImageData = thumbnail
            isThumbnail = !thumbnail.contains("original")
        }
    }
    
    private func isBase64Like(_ string: String) -> Bool {
        // 简单判断是否为Base64编码
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.count > 100 && !trimmed.contains(" ") && !trimmed.hasPrefix("http")
    }
    
    static func == (lhs: ClipboardEntry, rhs: ClipboardEntry) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - API 响应模型
struct ClipboardListResponse: Codable {
    let items: [ClipboardEntry]
    let total: Int?
    let page: Int?
    let pageSize: Int?
    let hasMore: Bool?
    
    enum CodingKeys: String, CodingKey {
        case items
        case total
        case page
        case pageSize = "page_size"
        case hasMore = "has_more"
    }
    
    // 自定义解码：支持数组或对象格式
    init(from decoder: Decoder) throws {
        // 尝试直接解码为数组
        if let arrayContainer = try? decoder.singleValueContainer(),
           let items = try? arrayContainer.decode([ClipboardEntry].self) {
            self.items = items
            self.total = items.count
            self.page = 1
            self.pageSize = items.count
            self.hasMore = false
            return
        }
        
        // 否则按对象格式解码
        let container = try decoder.container(keyedBy: CodingKeys.self)
        items = try container.decode([ClipboardEntry].self, forKey: .items)
        total = try container.decodeIfPresent(Int.self, forKey: .total)
        page = try container.decodeIfPresent(Int.self, forKey: .page)
        pageSize = try container.decodeIfPresent(Int.self, forKey: .pageSize)
        hasMore = try container.decodeIfPresent(Bool.self, forKey: .hasMore)
    }
    
    // 便捷属性
    var hasMoreItems: Bool { hasMore ?? false }
}

