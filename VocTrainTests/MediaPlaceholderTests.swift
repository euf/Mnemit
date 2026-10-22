import Testing

@testable import VocTrain

/// What a side without text shows in a list: the image's symbol before the sound's, nothing for a side with text or without media.
struct MediaPlaceholderTests {
    @Test func aSideWithMediaOnlyGetsAPlaceholder() {
        #expect(MediaPlaceholder(text: "", image: "a.jpg", audio: nil) == .image)
        #expect(MediaPlaceholder(text: " \n", image: nil, audio: "b.mp3") == .sound)
        #expect(MediaPlaceholder(text: "", image: "a.jpg", audio: "b.mp3") == .image)
        #expect(MediaPlaceholder.image.symbol == "photo")
        #expect(MediaPlaceholder.sound.symbol == "speaker.wave.2")
    }

    @Test func aSideWithTextOrWithoutMediaGetsNone() {
        #expect(MediaPlaceholder(text: "σπίτι", image: "a.jpg", audio: "b.mp3") == nil)
        #expect(MediaPlaceholder(text: "", image: nil, audio: nil) == nil)
    }
}
