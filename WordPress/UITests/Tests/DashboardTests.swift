import UITestsFoundation
import XCTest

// These tests are Jetpack only.
class DashboardTests: XCTestCase {
    override func setUpWithError() throws {
        setUpTestSuite()

        try LoginFlow.loginWithoutSelectingSite(
            siteUrl: WPUITestCredentials.testWPcomPaidSite,
            email: WPUITestCredentials.testWPcomUserEmail,
            password: WPUITestCredentials.testWPcomPassword
        )
    }

    override func tearDownWithError() throws {
        takeScreenshotOfFailedTest()
    }

    func testFreeToPaidCardNavigation() throws {
        try LoginEpilogueScreen()
            .continueWithSelectedSite(title: WPUITestCredentials.testWPcomFreeSite)
            .scrollToFreeToPaidPlansCard()
            .verifyFreeToPaidPlansCard()
            .tapFreeToPaidPlansCard()
            .assertScreenIsLoaded()
            .selectDomain()
            .goToPlanSelection()
            .assertScreenIsLoaded()
    }

    func testPagesCardHeaderNavigation() throws {
        try LoginEpilogueScreen()
            .continueWithSelectedSite(title: WPUITestCredentials.testWPcomPaidSite)
            .scrollToPagesCard()
            .verifyPagesCard()
            .verifyPagesCard(hasPage: "Blog")
            .verifyPagesCard(hasPage: "Shop")
            .verifyPagesCard(hasPage: "Cart")
            .tapPagesCardHeader()
            .assertScreenIsLoaded()
            .verifyPagesScreen(hasPage: "Blog")
            .verifyPagesScreen(hasPage: "Shop")
            .verifyPagesScreen(hasPage: "Cart")
    }

    func testActivityLogCardHeaderNavigation() throws {
        try LoginEpilogueScreen()
            .continueWithSelectedSite(title: WPUITestCredentials.testWPcomPaidSite)
            .scrollToActivityLogCard()
            .verifyActivityLogCard()
            .verifyActivityLogCard(hasActivityPartial: "Enabled Jetpack Social")
            .verifyActivityLogCard(hasActivityPartial: "The Jetpack connection")
            .verifyActivityLogCard(hasActivityPartial: "This site is connected to")
            .tapActivityLogCardHeader()
            .assertScreenIsLoaded()
            .verifyActivityLogScreen(hasActivityPartial: "Enabled Jetpack Social")
            .verifyActivityLogScreen(hasActivityPartial: "The Jetpack connection")
            .verifyActivityLogScreen(hasActivityPartial: "This site is connected to")
    }
}
