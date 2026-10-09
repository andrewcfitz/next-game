import Foundation
import Testing

struct AppGroupTests {
    @Test func containerFallsBackOutsideAnAppGroup() {
        #expect(AppGroup.containerURL.path().isEmpty == false)
    }

    @Test func readsTheGroupFromInfoPlist() {
        #expect(AppGroup.groupID(infoDictionary: ["NextGameAppGroup": "group.biz.fitz.NextGame"]) == "group.biz.fitz.NextGame")
    }

    @Test func rejectsMissingEmptyOrUnexpandedGroups() {
        #expect(AppGroup.groupID(infoDictionary: nil) == nil)
        #expect(AppGroup.groupID(infoDictionary: [:]) == nil)
        #expect(AppGroup.groupID(infoDictionary: ["NextGameAppGroup": ""]) == nil)
        #expect(AppGroup.groupID(infoDictionary: ["NextGameAppGroup": "$(NEXTGAME_APP_GROUP)"]) == nil)
    }
}
