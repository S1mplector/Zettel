import AppKit
import Foundation

public enum AttributedTextArchive {
    public static func encode(_ attributedString: NSAttributedString?) -> Data? {
        guard let attributedString, attributedString.length > 0 else {
            return nil
        }

        return try? attributedString.data(
            from: NSRange(location: 0, length: attributedString.length),
            documentAttributes: [
                .documentType: NSAttributedString.DocumentType.rtfd,
            ]
        )
    }

    public static func decode(_ data: Data?) -> NSAttributedString {
        guard let data else {
            return NSAttributedString(string: "")
        }

        if let attributedString = try? NSAttributedString(
            data: data,
            options: [
                .documentType: NSAttributedString.DocumentType.rtfd,
            ],
            documentAttributes: nil
        ) {
            return attributedString
        }

        guard
            let unarchiver = try? NSKeyedUnarchiver(forReadingFrom: data)
        else {
            return NSAttributedString(string: "")
        }

        unarchiver.requiresSecureCoding = false
        let attributedString = unarchiver.decodeObject(forKey: NSKeyedArchiveRootObjectKey) as? NSAttributedString
        unarchiver.finishDecoding()
        return attributedString ?? NSAttributedString(string: "")
    }
}
