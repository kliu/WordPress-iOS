import XCTest
import WordPressAPI
@testable import WordPress

final class Blog_RestAPITests: CoreDataTestCase {
    let loginDetails = WpApiApplicationPasswordDetails(
        siteUrl: "https://example.com",
        userLogin: "test@example.com",
        password: "StrongPassword!"
    )

    let testKeychain = TestKeychain()

    private var blog: Blog!

    override func setUp() async throws {
        _ = try await Blog.createRestApiBlog(with: loginDetails, in: contextManager, using: testKeychain)
        self.blog = try XCTUnwrap(contextManager.mainContext.fetch(NSFetchRequest<Blog>(entityName: "Blog")).first)
    }

    func testThatCreateRestApiBlogStoresUrl() throws {
        XCTAssertEqual(try blog.getUrl().absoluteString, loginDetails.siteUrl)
    }

    func testThatCreateRestApiBlogStoresUsername() throws {
        XCTAssertEqual(try blog.getUsername(), loginDetails.userLogin)
    }

    func testThatCreateRestApiBlogStoresPassword() throws {
        XCTAssertEqual(try blog.getPassword(using: testKeychain), loginDetails.password)
    }

    func testThatCreateRestApiBlogStoresSiteIdentifier() throws {
        XCTAssertEqual(try blog.getSiteIdentifier(), loginDetails.derivedSiteId)
    }

    func testThatCreateRestApiBlogStoresDerivedXMLRPCEndpoint() throws {
        try XCTAssertEqual(blog.getXMLRPCEndpoint(), loginDetails.derivedXMLRPCRoot)
    }

    func testThatExistingBlogWithInvalidUrlThrowsErrorOnAccess() throws {
        blog.url = ""
        XCTAssertThrowsError(try blog.getUrl())
    }

    func testThatExistingBlogWithNoUrlThrowsErrorOnAccess() throws {
        blog.url = nil
        XCTAssertThrowsError(try blog.getUrl())
    }

    func testThatExistingBlogWithNoUsernameThrowsErrorOnAccess() throws {
        blog.username = nil
        XCTAssertThrowsError(try blog.getUsername())
    }

    func testThatExistingBlogWithNoSiteIdentifierThrowsErrorOnAccess() throws {
        blog.apiKey = nil
        XCTAssertThrowsError(try blog.getSiteIdentifier())
    }

    func testThatBlogWithNoXMLRPCEndpointThrowsErrorOnAccess() throws {
        blog.xmlrpc = nil
        XCTAssertThrowsError(try blog.getXMLRPCEndpoint())
    }

    func testThatBlogWithInvalidXMLRPCEndpointThrowsErrorOnAccess() throws {
        blog.xmlrpc = ""
        XCTAssertThrowsError(try blog.getXMLRPCEndpoint())
    }

    func testThatExistingBlogCanBeLookedUp() throws {
        XCTAssertNotNil(try Blog.lookupRestApiBlog(with: blog.getSiteIdentifier(), in: mainContext))
    }

    func testThatExistingBlogCausesHasRestApiBlogToReturnTrue() throws {
        XCTAssertTrue(try Blog.hasRestApiBlog(with: blog.getSiteIdentifier(), in: mainContext))
    }

    func testThatNoExistingBlogCausesHasRestApiBlogToReturnFalse() throws {
        XCTAssertFalse(try Blog.hasRestApiBlog(with: "invalid identifier", in: mainContext))
    }
}
