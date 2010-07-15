//
//  WFAsyncThread.h
//  Workflow
//
//  Created by jlopez on 7/14/10.
//  Copyright 2010 JLA. All rights reserved.
//

@interface WFAsyncThread : NSThread {
@private
  BOOL running;
}

+ (WFAsyncThread *)sharedInstance;

@end
