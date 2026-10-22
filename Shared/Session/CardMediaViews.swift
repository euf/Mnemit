import SwiftUI
import VocabCore

#if os(iOS)
import UIKit
private typealias PlatformImage = UIImage
#else
import AppKit
private typealias PlatformImage = NSImage
#endif

/// The images of a deck, decoded once per file name: a name says what the file holds, so two
/// decks that use one name share the image. Read on the main thread only, by the views.
@MainActor
enum MediaImages {
    private static let cache = NSCache<NSString, PlatformImage>()

    /// The image `name` of `media`; `nil` if the deck has no such file or it isn't an image.
    static func image(named name: String, in media: DeckMedia) -> Image? {
        let image: PlatformImage
        if let cached = cache.object(forKey: name as NSString) {
            image = cached
        } else if let data = media.contents(of: name), let decoded = PlatformImage(data: data) {
            cache.setObject(decoded, forKey: name as NSString)
            image = decoded
        } else {
            return nil
        }
        #if os(iOS)
        return Image(uiImage: image)
        #else
        return Image(nsImage: image)
        #endif
    }
}

/// The image of a side of a card, scaled to fit with rounded corners; nothing if the side has
/// none or the deck's file can't be read. `maxHeight` is the most it takes.
struct SideImage: View {
    var name: String?
    var media: DeckMedia?
    var maxHeight: CGFloat
    var alignment = Alignment.center

    var body: some View {
        if let name, let media, let image = MediaImages.image(named: name, in: media) {
            image
                .resizable()
                .scaledToFit()
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .frame(maxHeight: maxHeight)
                .frame(maxWidth: .infinity, alignment: alignment)
                .accessibilityLabel(Text("Image"))
        }
    }
}

/// What a side without text shows in a list instead of an empty cell: the symbol and the word
/// of what it has, an image before a sound.
enum MediaPlaceholder: Equatable {
    case image, sound

    /// `nil` if the side has text, or has neither an image nor a sound.
    init?(text: String, image: String?, audio: String?) {
        guard CardText.trimmed(text).isEmpty else { return nil }
        if image != nil {
            self = .image
        } else if audio != nil {
            self = .sound
        } else {
            return nil
        }
    }

    var symbol: String { self == .image ? "photo" : "speaker.wave.2" }
    var title: LocalizedStringKey { self == .image ? "Image" : "Sound" }
}

/// A side of a card in a list: its text, or for a side with media only its placeholder in the
/// secondary colour.
struct SideText: View {
    var text: String
    var image: String?
    var audio: String?

    var body: some View {
        if let placeholder = MediaPlaceholder(text: text, image: image, audio: audio) {
            HStack(spacing: Spacing.hairline) {
                Image(systemName: placeholder.symbol)
                    .imageScale(.small)
                Text(placeholder.title)
            }
            .foregroundStyle(.secondary)
        } else {
            Text(text)
        }
    }
}
