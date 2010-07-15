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


- (void)scheduleExecution:(void (^)(void))block {
  dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), block);
}


- (void)processExecutionResult:(NSNumber *)executionResult {
  // notifyCompletionCalled?   execRes | setCompleted?
  //           N                 nil   |      -       error, must call notifyCompletion if returning void
  //           Y                 nil   |      -       notify step
  //           N                  N    |      Y       already completed, notify step
  //           Y                  N    |      -       error, must not call notifyCompletion if already complete
  //           N                  Y    |      Y       silent ack, notify step
  //           Y                  Y    |      -       notify step
  BOOL f = [executionResult boolValue];
  if (!notifyCompletionCalled && !executionResult)
    NSAssert1(NO, @"%@ - notifyCompletion must be called if method returns void", step);
  if (notifyCompletionCalled && !executionResult)
    f = YES;
  if (!notifyCompletionCalled && !f)
    completed = YES;
  if (notifyCompletionCalled && !f)
    NSAssert1(NO, @"%@ - notifyCompletion must not be called if method returns NO", step);
  if (!notifyCompletionCalled && f)
    completed = YES;
  [step notifyTokenCompletion:self];
}


@end
