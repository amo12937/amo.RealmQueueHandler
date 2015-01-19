//
//  RealmQueueHandler.swift
//  RealmQueueHandler
//
//  Created by 安野周太郎 on 2015/01/19.
//  Copyright (c) 2015年 amo. All rights reserved.
//

import Foundation
import Realm

public class QueueHandler {
    private let queue: dispatch_queue_t
    private let basePath: String
    
    public init(basePath: String? = nil, queue: dispatch_queue_t? = nil) {
        self.queue = queue ?? dispatch_queue_create("amo.queue.realm_queue_hander", DISPATCH_QUEUE_SERIAL)
        self.basePath = basePath ?? NSFileManager
            .defaultManager()
            .URLForDirectory(
                .CachesDirectory,
                inDomain: .UserDomainMask,
                appropriateForURL: nil,
                create: true,
                error: nil
            )!.path!
    }
    
    private func createRealm(path: String) -> RLMRealm {
        return RLMRealm(path: "\(basePath)/\(path)")
    }
    
    public func writeTransaction(realmPath: String, callback: (realm: RLMRealm) -> (Bool)) {
        dispatch_barrier_async(self.queue, { () -> Void in
            let realm = self.createRealm(realmPath)
            realm.beginWriteTransaction()
            if callback(realm: realm) {
                realm.commitWriteTransaction()
            } else {
                realm.cancelWriteTransaction()
            }
        })
    }
    
    public func readTransaction(realmPath: String, callback: (realm: RLMRealm) -> ()) {
        dispatch_async(self.queue, { () -> Void in
            let realm = self.createRealm(realmPath)
            callback(realm: realm)
        })
    }
    
    public func barrierReadTransaction(realmPath: String, callback: (realm: RLMRealm) -> ()) {
        dispatch_barrier_async(self.queue, { () -> Void in
            let realm = self.createRealm(realmPath)
            callback(realm: realm)
        })
    }
}

