//
//  Category.swift
//  Pastee
//
//  分类数据模型
//

import Foundation

struct Category: Codable, Identifiable, Equatable {
    var id: String
    var name: String
    var itemCount: Int?
    var isShared: Bool?
    var allowMemberEdit: Bool?
    var isJoined: Bool?
    var isCreator: Bool?
    var createdAt: String?
    
    // 本地状态
    var isSelected: Bool = false
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case itemCount = "item_count"
        case isShared = "is_shared"
        case allowMemberEdit = "allow_member_edit"
        case isJoined = "is_joined"
        case isCreator = "is_creator"
        case createdAt = "created_at"
    }
    
    init(id: String = "", name: String = "", itemCount: Int? = nil) {
        self.id = id
        self.name = name
        self.itemCount = itemCount
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // ID可能是数字或字符串
        if let intId = try? container.decode(Int.self, forKey: .id) {
            id = String(intId)
        } else {
            id = try container.decode(String.self, forKey: .id)
        }
        
        name = try container.decode(String.self, forKey: .name)
        itemCount = try container.decodeIfPresent(Int.self, forKey: .itemCount)
        isShared = try container.decodeIfPresent(Bool.self, forKey: .isShared)
        allowMemberEdit = try container.decodeIfPresent(Bool.self, forKey: .allowMemberEdit)
        isJoined = try container.decodeIfPresent(Bool.self, forKey: .isJoined)
        isCreator = try container.decodeIfPresent(Bool.self, forKey: .isCreator)
        createdAt = try container.decodeIfPresent(String.self, forKey: .createdAt)
    }
    
    static func == (lhs: Category, rhs: Category) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - API 响应包装
struct CategoriesResponse: Codable {
    let categories: [Category]
}

