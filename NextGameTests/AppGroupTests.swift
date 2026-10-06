import Foundation
import Testing

struct AppGroupTests {
    @Test func containerFallsBackOutsideAnAppGroup() {
        #expect(AppGroup.containerURL.path().isEmpty == false)
    }
}
