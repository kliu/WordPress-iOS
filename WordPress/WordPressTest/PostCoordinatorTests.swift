import UIKit
import XCTest
import Nimble
import WordPressFlux

@testable import WordPress

class PostCoordinatorTests: CoreDataTestCase {

    override func setUp() {
        super.setUp()
        contextManager.useAsSharedInstance(untilTestFinished: self)
        TestAnalyticsTracker.setup()
    }

    override func tearDown() {
        super.tearDown()
        TestAnalyticsTracker.tearDown()
    }

    func testDoNotUploadAPostWithFailedMedia() {
        let postServiceMock = PostServiceMock()
        let post = PostBuilder(mainContext)
            .with(image: "test.jpeg", status: .failed)
            .with(remoteStatus: .local)
            .build()
        let mediaCoordinatorMock = MediaCoordinatorMock(media: post.media.first!, mediaState: .failed(error: .testInstance()))
        let postCoordinator = PostCoordinator(mainService: postServiceMock, mediaCoordinator: mediaCoordinatorMock, isSyncPublishingEnabled: false)

        postCoordinator.save(post)

        expect((try! self.mainContext.existingObject(with: post.objectID) as! Post).remoteStatus).toEventually(equal(.failed))
        expect(postServiceMock.didCallUploadPost).to(beFalse())
    }

    func testUploadAPostWithNoFailedMedia() {
        let postServiceMock = PostServiceMock()
        let postCoordinator = PostCoordinator(mainService: postServiceMock)
        let post = PostBuilder(mainContext)
            .with(image: "test.jpeg")
            .build()

        postCoordinator.save(post)

        expect(postServiceMock.didCallUploadPost).to(beTrue())
    }

    func testEventuallyMarkThePostRemoteStatusAsUploading() {
        let postServiceMock = PostServiceMock()
        let postCoordinator = PostCoordinator(mainService: postServiceMock)
        let post = PostBuilder(mainContext)
            .with(image: "test.jpeg")
            .build()

        postCoordinator.save(post)

        expect(post.remoteStatus).toEventually(equal(.pushing))
    }

    func testAttemptCountIsIncrementedAfterFailingToAutomaticallyUpload() {
        let postServiceMock = PostServiceMock()
        let postCoordinator = PostCoordinator(mainService: postServiceMock)
        let post = PostBuilder(mainContext).build()

        postCoordinator.save(post, automatedRetry: true)

        expect(post.autoUploadAttemptsCount).to(equal(1))
    }

    func testAttemptCountIsResetWhenNotAutomaticallyUpload() {
        let postServiceMock = PostServiceMock()
        let postCoordinator = PostCoordinator(mainService: postServiceMock)
        let post = PostBuilder(mainContext).with(autoUploadAttemptsCount: 3).build()

        postCoordinator.save(post, automatedRetry: false)

        expect(post.autoUploadAttemptsCount).to(equal(0))
    }

    func testReturnPostWhenServiceSucceed() {
        let postServiceMock = PostServiceMock(managedObjectContext: mainContext)
        let postCoordinator = PostCoordinator(mainService: postServiceMock)
        let post = PostBuilder(mainContext).build()
        postServiceMock.returnPost = post
        var returnedPost: AbstractPost?

        postCoordinator.save(post) { result in
            switch result {
            case .success(let post):
                returnedPost = post
            default:
                break
            }
        }

        expect(returnedPost).toEventuallyNot(beNil())
    }

    func testReturnErrorWhenServiceFails() {
        let postServiceMock = PostServiceMock(managedObjectContext: mainContext)
        let postCoordinator = PostCoordinator(mainService: postServiceMock)
        let post = PostBuilder(mainContext).build()
        postServiceMock.returnError = NSError(domain: "", code: 1, userInfo: nil)
        var returnedError: Error?

        postCoordinator.save(post) { result in
            switch result {
            case .failure(let error):
                returnedError = error
            default:
                break
            }
        }

        expect(returnedError).toEventuallyNot(beNil())
    }

    func testReturnErrorWhenMediaFails() {
        let postServiceMock = PostServiceMock()
        let post = PostBuilder(mainContext)
            .with(image: "test.jpeg", status: .failed)
            .with(remoteStatus: .local)
            .build()
        let mediaCoordinatorMock = MediaCoordinatorMock(media: post.media.first!, mediaState: .failed(error: .testInstance()))
        let postCoordinator = PostCoordinator(mainService: postServiceMock, mediaCoordinator: mediaCoordinatorMock, isSyncPublishingEnabled: false)
        var returnedError: Error?

        postCoordinator.save(post) { result in
            switch result {
            case .failure(let error):
                returnedError = error
            default:
                break
           }
        }

        expect(returnedError).toEventuallyNot(beNil())
    }

    func testChangeDraftToPublishWhenPublishing() {
        let post = PostBuilder(mainContext).drafted().build()
        let postServiceMock = PostServiceMock(managedObjectContext: mainContext)
        let postCoordinator = PostCoordinator(mainService: postServiceMock)

        postCoordinator.publish(post)

        expect(post.status).to(equal(.publish))
    }

    func testDoNotChangeDateCreatedForAScheduledPost() {
        let post = PostBuilder(mainContext).with(dateCreated: Date(timeIntervalSince1970: 50)).scheduled().build()
        let postServiceMock = PostServiceMock(managedObjectContext: mainContext)
        let postCoordinator = PostCoordinator(mainService: postServiceMock)

        postCoordinator.publish(post)

        expect(post.date_created_gmt).to(equal(Date(timeIntervalSince1970: 50)))
    }

    func testCallPostCoordinatorToSaveAPost() {
        let post = PostBuilder(mainContext).drafted().build()
        let postServiceMock = PostServiceMock(managedObjectContext: mainContext)
        let postCoordinator = PostCoordinator(mainService: postServiceMock)

        postCoordinator.publish(post)

        expect(postServiceMock.didCallUploadPost).to(beTrue())
    }

    func testChangePostToDraftWhenMovingToDraft() {
        let post = PostBuilder(mainContext).published().build()
        let postServiceMock = PostServiceMock(managedObjectContext: mainContext)
        let postCoordinator = PostCoordinator(mainService: postServiceMock, isSyncPublishingEnabled: false)

        postCoordinator.moveToDraft(post)

        expect(post.status).to(equal(.draft))
    }

    func testSavingSuccessfullyWillDispatchASuccessNotice() {
        // Arrange
        let post = PostBuilder(mainContext)
            .with(title: "Sint dolorem quo")
            .with(status: .publish)
            .with(remoteStatus: .local)
            .build()

        let postServiceMock = PostServiceMock(managedObjectContext: mainContext)
        postServiceMock.returnPost = post

        let actionDispatcherFacadeMock = ActionDispatcherFacadeMock()

        let postCoordinator = PostCoordinator(mainService: postServiceMock, actionDispatcherFacade: actionDispatcherFacadeMock)

        // Act
        var result: Result<AbstractPost, Error>? = nil
        waitUntil(timeout: DispatchTimeInterval.seconds(2)) { done in
            postCoordinator.save(post) { aResult in
                result = aResult
                done()
            }
        }

        // Assert
        expect(result).notTo(beNil())
        expect(actionDispatcherFacadeMock.dispatchedActions).toEventuallyNot(beEmpty())

        guard case let NoticeAction.post(notice)? = actionDispatcherFacadeMock.dispatchedActions.first else {
            assertionFailure("The action should be a NoticeAction")
            return
        }

        expect(notice.feedbackType).to(equal(.success))
        expect(notice.message).to(contain("Sint dolorem quo"))
    }

    func testFailingToSaveWillDispatchAFailedNotice() {
        // Arrange
        let post = PostBuilder(mainContext)
            .with(title: "Sit neque qui")
            .with(status: .publish)
            .with(remoteStatus: .local)
            .build()

        let postServiceMock = PostServiceMock(managedObjectContext: mainContext)
        postServiceMock.returnError = NSError(domain: "", code: 1, userInfo: nil)

        let actionDispatcherFacadeMock = ActionDispatcherFacadeMock()

        let postCoordinator = PostCoordinator(mainService: postServiceMock, actionDispatcherFacade: actionDispatcherFacadeMock)

        // Act
        var result: Result<AbstractPost, Error>? = nil
        waitUntil(timeout: DispatchTimeInterval.seconds(2)) { done in
            postCoordinator.save(post) { aResult in
                result = aResult
                done()
            }
        }

        // Assert
        expect(result).notTo(beNil())
        expect(actionDispatcherFacadeMock.dispatchedActions).toEventuallyNot(beEmpty())

        guard case let NoticeAction.post(notice)? = actionDispatcherFacadeMock.dispatchedActions.first else {
            assertionFailure("The action should be a NoticeAction")
            return
        }

        expect(notice.feedbackType).to(equal(.error))
        expect(notice.message).to(contain("Sit neque qui"))
    }

    func testFailingToSaveBecauseOfMediaErrorsWillDispatchAFailedNotice() {
        // Arrange
        let post = PostBuilder(mainContext)
            .with(title: "Ipsa aliquam")
            .with(image: "test.jpeg", status: .failed)
            .with(status: .publish)
            .with(remoteStatus: .local)
            .build()

        let mediaCoordinatorMock = MediaCoordinatorMock(media: post.media.first!, mediaState: .failed(error: .testInstance()))
        let postServiceMock = PostServiceMock(managedObjectContext: mainContext)
        let actionDispatcherFacadeMock = ActionDispatcherFacadeMock()

        let postCoordinator = PostCoordinator(mainService: postServiceMock, mediaCoordinator: mediaCoordinatorMock, actionDispatcherFacade: actionDispatcherFacadeMock, isSyncPublishingEnabled: false)

        // Act
        var result: Result<AbstractPost, Error>? = nil
        waitUntil(timeout: DispatchTimeInterval.seconds(2)) { done in
            postCoordinator.save(post) { aResult in
                result = aResult
                done()
            }
        }

        // Assert
        expect(result).notTo(beNil())
        expect(actionDispatcherFacadeMock.dispatchedActions).toEventuallyNot(beEmpty())

        guard case let NoticeAction.post(notice)? = actionDispatcherFacadeMock.dispatchedActions.first else {
            XCTFail("The action should be a NoticeAction")
            return
        }

        expect(notice.feedbackType).to(equal(.error))
        expect(notice.message).to(contain("Ipsa aliquam"))
    }

    func testFailingToSaveBecauseOfMediaErrorsWillWillCallCompletionBlockOnlyOnce() {
        // Arrange
        let post = PostBuilder(mainContext)
            .with(image: "test.jpeg", status: .failed)
            .with(image: "test-002.jpeg", status: .failed)
            .build()

        let onUpdateParameters = post.media.reduce(into: [Media: MediaCoordinator.MediaState]()) { dict, media in
            dict[media] = MediaCoordinator.MediaState.failed(error: .testInstance())
        }
        let mediaCoordinatorMock = MediaCoordinatorMock(onUpdateParameters: onUpdateParameters)

        let postServiceMock = PostServiceMock(managedObjectContext: mainContext)

        let postCoordinator = PostCoordinator(mainService: postServiceMock, mediaCoordinator: mediaCoordinatorMock, isSyncPublishingEnabled: false)

        // Act
        var results = [Result<AbstractPost, Error>]()
        waitUntil(timeout: DispatchTimeInterval.seconds(2)) { done in
            postCoordinator.save(post) { aResult in
                results.append(aResult)
                done()
            }
        }

        // Assert
        expect(results).to(haveCount(1))
    }

    func testPostSavedButNotReturned() {
        let postServiceMock = PostServiceMock()
        let postCoordinator = PostCoordinator(mainService: postServiceMock)
        let post = PostBuilder(mainContext).build()
        postServiceMock.returnNilPost = true
        var returnedError: Error?

        postCoordinator.save(post) { result in
            switch result {
            case .failure(let error):
                returnedError = error
            default:
                break
           }
        }

        expect(returnedError).toNot(beNil())
    }
}

class PostServiceMock: PostService {
    struct UploadPostInvocation {
        let post: AbstractPost
        let forceDraftIfCreating: Bool
    }

    private(set) var didCallAutoSave = false

    private(set) var lastUploadPostInvocation: UploadPostInvocation?
    var didCallUploadPost: Bool {
        return lastUploadPostInvocation != nil
    }

    var returnPost: AbstractPost?
    var returnError: Error?

    /// Succeed in uploading the post but return nil
    var returnNilPost = false

    // Sync posts variables
    var syncShouldSucceed = true
    var syncPostsCalled = false
    var returnSyncedPosts: [AbstractPost]?

    override func uploadPost(_ post: AbstractPost, forceDraftIfCreating: Bool, success: ((AbstractPost?) -> Void)?, failure: ((Error?) -> Void)?) {
        lastUploadPostInvocation = UploadPostInvocation(post: post, forceDraftIfCreating: forceDraftIfCreating)

        if let post = returnPost {
            post.remoteStatus = .sync
            success?(post)
        }

        if returnNilPost {
            success?(nil)
        }

        if let error = returnError {
            post.remoteStatus = .failed
            failure?(error)
        }
    }

    override func autoSave(_ post: AbstractPost, success: ((AbstractPost, String) -> Void)?, failure: @escaping (Error?) -> Void) {
        didCallAutoSave = true
    }

    override func syncPosts(ofType postType: PostServiceType, with options: PostServiceSyncOptions, for blog: Blog, success: @escaping PostServiceSyncSuccess, failure: @escaping PostServiceSyncFailure) {
        syncPostsCalled = true
        if syncShouldSucceed {
            success(returnSyncedPosts)
        }
        else {
            failure(nil)
        }
    }
}

private class MediaCoordinatorMock: MediaCoordinator {
    private var onUpdateParameters = [Media: MediaState]()

    init(media: Media, mediaState: MediaState) {
        onUpdateParameters[media] = mediaState
    }

    init(onUpdateParameters: [Media: MediaState]) {
        self.onUpdateParameters = onUpdateParameters
    }

    override func addObserver(_ onUpdate: @escaping MediaCoordinator.ObserverBlock, for media: Media? = nil) -> UUID {
        return UUID()
    }

    override func addObserver(_ onUpdate: @escaping MediaCoordinator.ObserverBlock, forMediaFor post: AbstractPost) -> UUID {
        DispatchQueue.main.async {
            self.onUpdateParameters.forEach { media, mediaState in
                onUpdate(media, mediaState)
            }
        }
        return UUID()
    }

    override func retryMedia(_ media: Media, automatedRetry: Bool = false, analyticsInfo: MediaAnalyticsInfo? = nil) {
        // noop
    }
}

private class ActionDispatcherFacadeMock: ActionDispatcherFacade {
    private(set) var dispatchedActions = [Action]()

    override func dispatch(_ action: Action) {
        dispatchedActions.append(action)
    }
}
