//
//  RealmQueueHandlerTests.swift
//  RealmQueueHandlerTests
//
//  Created by 安野周太郎 on 2015/01/19.
//  Copyright (c) 2015年 amo. All rights reserved.
//

import UIKit
import XCTest
import Realm
import RealmQueueHandler

class MockObject: RLMObject {
    dynamic var key = 0
    dynamic var val = 0
    
    override class func primaryKey() -> String! {
        return "key"
    }
}

class RealmQueueHandlerTests: XCTestCase {
    var qh: QueueHandler!
    let path = "user.realm"
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
        qh = QueueHandler()
        qh.writeTransaction(path, callback: { (realm) -> (Bool) in
            realm.deleteAllObjects()
            return true
        })
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func test_書き込みはwriteTransactionが呼ばれた順に行われる() {
        let expectation = self.expectationWithDescription("test_concurrent")
        
        let key = 0
        let n = 100
        
        for i in 0..<n {
            qh.writeTransaction(path) { (realm) -> (Bool) in
                let old: MockObject! = MockObject(inRealm: realm, forPrimaryKey: key)
                if (old != nil && old.val >= i) {
                    XCTFail("expected old.val ( = \(old.val) ) to be always smaller than i ( = \(i))")
                }
                MockObject.createOrUpdateInRealm(realm, withObject: [
                    "key": key,
                    "val": i
                    ])
                return true
            }
        }
        
        qh.writeTransaction(path) { (realm) -> (Bool) in
            expectation.fulfill()
            return true
        }
        
        self.waitForExpectationsWithTimeout(1, handler: { (error) -> Void in })
    }
}
