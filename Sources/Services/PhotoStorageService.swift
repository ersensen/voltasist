// PhotoStorageService.swift
// VoltAsist

import UIKit
import Foundation

struct PhotoStorageService {

    private static var baseDir: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("maintenance", isDirectory: true)
    }

    static func directory(for entityID: UUID) -> URL {
        baseDir.appendingPathComponent(entityID.uuidString, isDirectory: true)
    }

    @discardableResult
    static func save(image: UIImage, entityID: UUID) -> UUID? {
        let dir = directory(for: entityID)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let photoID = UUID()
        let url = dir.appendingPathComponent("\(photoID.uuidString).jpg")
        guard let data = image.jpegData(compressionQuality: 0.78) else { return nil }
        try? data.write(to: url, options: .atomic)
        return photoID
    }

    static func load(photoID: UUID, entityID: UUID) -> UIImage? {
        let url = directory(for: entityID).appendingPathComponent("\(photoID.uuidString).jpg")
        guard let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }

    static func delete(photoID: UUID, entityID: UUID) {
        let url = directory(for: entityID).appendingPathComponent("\(photoID.uuidString).jpg")
        try? FileManager.default.removeItem(at: url)
    }

    static func thumbnail(photoID: UUID, entityID: UUID, size: CGSize = CGSize(width: 120, height: 120)) -> UIImage? {
        guard let image = load(photoID: photoID, entityID: entityID) else { return nil }
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in
            let scaleW = size.width / image.size.width
            let scaleH = size.height / image.size.height
            let scale = max(scaleW, scaleH)
            let scaledW = image.size.width * scale
            let scaledH = image.size.height * scale
            image.draw(in: CGRect(x: (size.width - scaledW) / 2,
                                  y: (size.height - scaledH) / 2,
                                  width: scaledW, height: scaledH))
        }
    }

    static func loadAll(photoIDs: [UUID], entityID: UUID) -> [(id: UUID, image: UIImage)] {
        photoIDs.compactMap { id in
            load(photoID: id, entityID: entityID).map { (id: id, image: $0) }
        }
    }
}
