import Testing

@testable import VocTrain
@testable import VocabCore

/// Which grades have a button: Forgot and Good always, Hard and Easy only with the setting and never on a first showing.
struct AnswerButtonsTests {
    @Test func twoButtonsUnlessTheSettingIsOnAndTheCardIsNotNew() {
        let two: [Grade] = [.again, .good]
        let four: [Grade] = [.again, .hard, .good, .easy]
        #expect(GradeChoice.buttonGrades(isNew: false, showsFourButtons: false) == two)
        #expect(GradeChoice.buttonGrades(isNew: true, showsFourButtons: false) == two)
        #expect(GradeChoice.buttonGrades(isNew: true, showsFourButtons: true) == two)
        #expect(GradeChoice.buttonGrades(isNew: false, showsFourButtons: true) == four)
    }

    /// Both apps read the one key; a renamed key would silently reset the setting.
    @Test func theSettingKeyIsStable() {
        #expect(GradeChoice.showsFourButtonsKey == "ShowsFourAnswerButtons")
    }
}
