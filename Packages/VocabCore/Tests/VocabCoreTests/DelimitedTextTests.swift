import Foundation
import Testing
import VocabCore

struct DelimitedTextTests {
    @Test func plainFieldsStayUnquoted() {
        let text = DelimitedText.encode([["dom", "Haus", ""], ["kot", "Katze", "Tier"]], delimiter: .comma)
        #expect(text == "dom,Haus,\r\nkot,Katze,Tier\r\n")
    }

    @Test func quotesFieldsThatNeedIt() {
        let text = DelimitedText.encode([["a, b", "sagt \"ja\"", "zwei\nZeilen", "a;b"]], delimiter: .comma)
        #expect(text == "\"a, b\",\"sagt \"\"ja\"\"\",\"zwei\nZeilen\",a;b\r\n")
    }

    @Test func quotesOnlyForTheChosenDelimiter() {
        #expect(DelimitedText.encode([["a, b", "c\td"]], delimiter: .tab) == "a, b\t\"c\td\"\r\n")
        #expect(DelimitedText.encode([["a, b", "c;d"]], delimiter: .semicolon) == "a, b;\"c;d\"\r\n")
    }

    @Test func noRowsGiveEmptyText() {
        #expect(DelimitedText.encode([], delimiter: .comma) == "")
    }
}

struct DelimitedTextParsingTests {
    @Test func parsesQuotedFieldsAndAnyLineBreak() {
        let text = "dom,\"Haus, Heim\",\r\n\"sagt \"\"ja\"\"\",\"zwei\nZeilen\",x\rkot,Katze,Tier"
        #expect(
            DelimitedText.parse(text, delimiter: .comma) == [
                ["dom", "Haus, Heim", ""],
                ["sagt \"ja\"", "zwei\nZeilen", "x"],
                ["kot", "Katze", "Tier"],
            ])
    }

    @Test func skipsEmptyLinesButKeepsEmptyFields() {
        #expect(DelimitedText.parse("a;b\n\n;c\n", delimiter: .semicolon) == [["a", "b"], ["", "c"]])
    }

    @Test func isLenientWithStrayQuotes() {
        #expect(DelimitedText.parse("5\" Zoll,cal\n\"a\"b,c", delimiter: .comma) == [["5\" Zoll", "cal"], ["ab", "c"]])
    }

    @Test func roundTripsEncodedRows() {
        let rows = [["Frage", "Antwort", "Hinweis"], ["a, b", "\"c\"", "d\ne"], ["dzień", "Tag", ""]]
        for delimiter in DelimitedText.Delimiter.allCases {
            #expect(DelimitedText.parse(DelimitedText.encode(rows, delimiter: delimiter), delimiter: delimiter) == rows)
        }
    }

    @Test func detectsTheDelimiter() {
        #expect(DelimitedText.detectedDelimiter(in: "dom\tHaus, Heim\nkot\tKatze") == .tab)
        #expect(DelimitedText.detectedDelimiter(in: "dom;Haus, Heim\nkot;Katze, Kater\npies;Hund") == .semicolon)
        #expect(DelimitedText.detectedDelimiter(in: "dom,Haus\nkot,\"Katze; Kater\"\npies,Hund") == .comma)
        #expect(DelimitedText.detectedDelimiter(in: "dom,Haus,Gebäude\nkot,Katze,Tier") == .comma)
    }

    @Test func detectsTheEncoding() {
        let utf8 = Data("\u{FEFF}dzień;Tag\n".utf8)
        #expect(DelimitedText.decode(utf8).rows == [["dzień", "Tag"]])

        let latin1 = Data([0x54, 0xFC, 0x72, 0x3B, 0x64, 0x72, 0x7A, 0x77, 0x69, 0x0A])  // "Tür;drzwi" in Latin-1
        #expect(DelimitedText.decode(latin1).rows == [["Tür", "drzwi"]])

        let windows = Data([0x80, 0x09, 0x65, 0x75, 0x72, 0x6F])  // "€\teuro" in Windows-1252
        #expect(DelimitedText.decode(windows).rows == [["€", "euro"]])

        let utf16 = "dom\tHaus\n".data(using: .utf16)!
        #expect(DelimitedText.decode(utf16).rows == [["dom", "Haus"]])
        #expect(DelimitedText.decode(utf16).delimiter == .tab)
    }
}

/// The header lines Anki reads at the top of a text file.
struct AnkiHeaderTests {
    @Test func writesTheHeaderLinesBeforeTheRows() {
        let rows = [["dom", "Haus", ""]]
        #expect(
            DelimitedText.encode(rows, delimiter: .tab, ankiColumns: ["Front", "Back", "Hint"])
                == "#separator:tab\r\n#html:false\r\n#columns:Front\tBack\tHint\r\ndom\tHaus\t\r\n")
        #expect(
            DelimitedText.encode(rows, delimiter: .comma, ankiColumns: ["Front", "Back", "Hint"])
                == "#separator:comma\r\n#html:false\r\n#columns:Front,Back,Hint\r\ndom,Haus,\r\n")
    }

    @Test func readsBackWhatItWrites() {
        let rows = [["dom", "Haus, Heim", "a\tb"], ["# kot", "Katze", ""]]
        for delimiter in DelimitedText.Delimiter.allCases {
            let columns = ["Front", "Back", "Hint"]
            let text = "\u{FEFF}" + DelimitedText.encode(rows, delimiter: delimiter, ankiColumns: columns)
            let decoded = DelimitedText.decode(Data(text.utf8))
            #expect(decoded.rows == rows)
            #expect(decoded.delimiter == delimiter)
            #expect(decoded.columns == columns)
        }
    }

    @Test func headerLinesAreNoRows() {
        let file = Data("#a comment\n#separator:semicolon\r\n#html:true\n#columns:Question;Answer\ndom;Haus\n".utf8)
        let decoded = DelimitedText.decode(file)
        #expect(decoded.rows == [["dom", "Haus"]])
        #expect(decoded.delimiter == .semicolon)
        #expect(decoded.columns == ["Question", "Answer"])
    }

    @Test func separatorNamesAndCharactersBothDecide() {
        // The rows hold a comma that detection would trip over: the header decides.
        #expect(DelimitedText.decode(Data("#separator:Tab\ndom\tHaus, Heim\nkot\tKatze, Kater\n".utf8)).delimiter == .tab)
        #expect(DelimitedText.decode(Data("#separator:;\ndom;Haus\n".utf8)).delimiter == .semicolon)
        // A separator we don't have leaves it to the detection.
        #expect(DelimitedText.decode(Data("#separator:pipe\ndom\tHaus\n".utf8)).delimiter == .tab)
    }

    @Test func onlyLinesAtTheTopAreHeaders() {
        #expect(DelimitedText.decode(Data("dom;Haus\n#kot;Katze\n".utf8)).columns == nil)
        #expect(DelimitedText.decode(Data("dom;Haus\n#kot;Katze\n".utf8)).rows == [["dom", "Haus"], ["#kot", "Katze"]])
    }
}
