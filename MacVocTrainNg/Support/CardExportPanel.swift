import AppKit
import SwiftUI
import UniformTypeIdentifiers
import VocabCore

extension CardExport {
    /// File ▸ Export Deck…: asks for the format and the file, then writes the cards.
    @MainActor
    static func run(cards: [Card], calendar: StudyCalendar, suggestedName: String) {
        let options = Options()
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [options.format.contentType]
        savePanel.nameFieldStringValue = suggestedName
        savePanel.message = String(localized: "Export \(cards.count) cards.")
        savePanel.prompt = String(localized: "Export")
        let accessory = NSHostingView(
            rootView: OptionsView(options: options) { format in
                savePanel.allowedContentTypes = [format.contentType]
            })
        accessory.frame.size = accessory.fittingSize
        savePanel.accessoryView = accessory
        guard savePanel.runModal() == .OK, let target = savePanel.url else { return }

        do {
            try data(of: cards, format: options.format, includingLearningState: options.includesLearningState, calendar: calendar)
                .write(to: target, options: .atomic)
        } catch {
            NSAlert.showWarning(String(localized: "Export failed"), message: error.localizedDescription)
        }
    }

    @Observable
    final class Options {
        var format = Format.csv
        var includesLearningState = false
    }

    private struct OptionsView: View {
        @Bindable var options: Options
        var formatChanged: (Format) -> Void

        var body: some View {
            Form {
                Picker("Format:", selection: $options.format) {
                    ForEach(Format.allCases, id: \.self) { format in
                        Text(format.title).tag(format)
                    }
                }
                .fixedSize()
                Toggle("Include learning state", isOn: $options.includesLearningState)
                    .help("Adds the maturity, the day the card is due and the number of reviews.")
            }
            .padding(12)
            .onChange(of: options.format) { _, format in
                formatChanged(format)
            }
        }
    }
}
