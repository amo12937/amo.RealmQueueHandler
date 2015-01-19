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

    func test_should_write_sequentially_in_the_order_of_calling_write_transaction() {
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
        
        qh.barrierReadTransaction(path) { (realm) -> () in
            expectation.fulfill()
            return
        }
        
        self.waitForExpectationsWithTimeout(1, handler: { (error) -> Void in })
    }
    
    func test_performance_of_write_transaction() {
        let key = 0
        var val = 0
        let getVal = { val++ }
        let n = 1000
        let semaphore = dispatch_semaphore_create(0)
        self.measureBlock { () -> Void in
            for i in 0..<n {
                println("-------------- \(i) --------------")
//                println("[              \(i)              ]")
                self.qh.writeTransaction(self.path) { (realm) -> (Bool) in
                    MockObject.createOrUpdateInRealm(realm, withObject: [
                        "key": key,
                        "val": getVal()
                        ])
                    return true
                }
            }
            
            self.qh.barrierReadTransaction(self.path) { (realm) -> () in
                dispatch_semaphore_signal(semaphore)
                return
            }
            
            let result = dispatch_semaphore_wait(semaphore, dispatch_time(DISPATCH_TIME_NOW, Int64(1 * NSEC_PER_SEC)))
            if (result != 0) {
                XCTFail("timeout expires.")
            }
        }
    }
    
    func test_should_be_overwritten_when_reading_after_writing() {
        let expectation = self.expectationWithDescription("test_writeのあとに登録されたreadTransactionでは確実に書き換わっている")
        let key = 0
        let val = 100
        let anotherVal = 200
        let n = 100
        
        for i in 0..<n {
            qh.readTransaction(path) { (realm) -> () in
                let entityOrNil = MockObject(inRealm: realm, forPrimaryKey: key)
                XCTAssertNil(entityOrNil)
            }
        }
        
        qh.writeTransaction(path) { (realm) -> (Bool) in
            MockObject.createOrUpdateInRealm(realm, withObject: [
                "key": key,
                "val": val
                ])
            return true
        }
        
        for i in 0..<n {
            qh.readTransaction(path) { (realm) -> () in
                let entityOrNil = MockObject(inRealm: realm, forPrimaryKey: key)
                if let entity = entityOrNil {
                    XCTAssertEqual(key, entity.key)
                    XCTAssertEqual(val, entity.val)
                } else {
                    XCTFail("\(i): expected entity not to be nil.")
                }
            }
        }
        
        qh.writeTransaction(path) { (realm) -> (Bool) in
            MockObject.createOrUpdateInRealm(realm, withObject: [
                "key": key,
                "val": anotherVal
                ])
            return true
        }
        
        for i in 0..<n {
            qh.readTransaction(path) { (realm) -> () in
                let entityOrNil = MockObject(inRealm: realm, forPrimaryKey: key)
                if let entity = entityOrNil {
                    XCTAssertEqual(key, entity.key)
                    XCTAssertEqual(anotherVal, entity.val)
                } else {
                    XCTFail("\(i): expected entity not to be nil.")
                }
            }
        }
        
        qh.barrierReadTransaction(path) { (realm) -> () in
            expectation.fulfill()
            return
        }
        
        self.waitForExpectationsWithTimeout(1, handler: { (error) -> Void in })
    }
    
    func test_performance_of_read_transaction() {
        let key = 0
        let val = 100
        let n = 100
        let semaphore = dispatch_semaphore_create(0)
        let time = dispatch_time(DISPATCH_TIME_NOW, Int64(1 * NSEC_PER_SEC))
        
        self.measureBlock { () -> Void in
            self.qh.writeTransaction(self.path) { (realm) -> (Bool) in
                MockObject.createOrUpdateInRealm(realm, withObject: [
                    "key": key,
                    "val": val
                    ])
                return true
            }
            
            for i in 0..<n {
                self.qh.readTransaction(self.path) { (realm) -> () in
                    let entityOrNil = MockObject(inRealm: realm, forPrimaryKey: key)
                    if let entity = entityOrNil {
                        XCTAssertEqual(key, entity.key)
                        XCTAssertEqual(val, entity.val)
                    } else {
                        XCTFail("\(i): expected entity not to be nil.")
                    }
                }
            }
            
            self.qh.barrierReadTransaction(self.path, callback: { (realm) -> () in
                dispatch_semaphore_signal(semaphore)
                return
            })
            
            let result = dispatch_semaphore_wait(semaphore, time)
            if (result != 0) {
                XCTFail("timeout expires.")
            }
        }
    }
}
