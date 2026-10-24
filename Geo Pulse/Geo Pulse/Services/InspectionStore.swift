import Foundation

@MainActor
protocol InspectionStore {
    func saveInspection(_ inspection: Inspection) throws
    func fetchAllInspections() throws -> [Inspection]
}

/// Durable image files referenced by inspection records. Names never contain paths.
@MainActor
struct PhotoStore {
    let directory: URL

    init(directory: URL = URL.applicationSupportDirectory.appendingPathComponent("InspectionPhotos")) {
        self.directory = directory
    }

    func save(_ data: Data) throws -> String {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let name = UUID().uuidString + ".jpg"
        try data.write(to: directory.appendingPathComponent(name), options: .atomic)
        return name
    }

    func url(for name: String) -> URL? {
        guard name == (name as NSString).lastPathComponent else { return nil }
        return directory.appendingPathComponent(name)
    }
}
