import Foundation

struct Account: Identifiable, Codable, Equatable, Hashable {
    let id: UUID
    var name: String
    let dataStoreID: UUID
    var lastURL: URL?
    let createdAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        dataStoreID: UUID = UUID(),
        lastURL: URL? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.dataStoreID = dataStoreID
        self.lastURL = lastURL
        self.createdAt = createdAt
    }
}
