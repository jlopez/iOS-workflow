//
//  WFAsyncToken.m
//  Workflow
//
//  Created by jlopez on 7/14/10.
//  Copyright 2010 JLA. All rights reserved.
//
#import "WFAsyncToken.h"

#import "WFAsyncThread.h"


@implementation WFAsyncToken


- (void)execute {
  // [step performAsyncStepWithToken:self] on asynThread
  [step performSelector:@selector(performAsyncStepWithToken:) onThread:[WFAsyncThread sharedInstance] withObject:self waitUntilDone:NO];
}


@end
