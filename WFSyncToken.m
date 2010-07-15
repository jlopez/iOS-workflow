//
//  WFSyncToken.m
//  Workflow
//
//  Created by jlopez on 7/14/10.
//  Copyright 2010 JLA. All rights reserved.
//
#import "WFSyncToken.h"

#import "WFStep.h"

@implementation WFSyncToken


- (void)execute {
  dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
    [step performSyncStepWithToken:self];
    NSAssert(completed, @"Sync step %@ failed to notify completion", step);
    [step notifyTokenCompletion:self];
  });
}


@end
