//
//  WFAsyncToken.m
//  Workflow
//
//  Created by jlopez on 7/14/10.
//  Copyright 2010 JLA. All rights reserved.
//
#import "WFAsyncToken.h"

#import "WFAsyncThread.h"
#import "WFStep.h"


@implementation WFAsyncToken


- (void)scheduleExecution:(void (^)(void))block {
  block = [[block copy] autorelease];
  [self performSelector:@selector(asyncExecute:) onThread:[WFAsyncThread sharedInstance] withObject:block waitUntilDone:NO];
}


- (void)asyncExecute:(void (^)(void))block {
  block();
}


- (void)processExecutionResult:(NSNumber *)executionResult {
  // notifyCompletionCalled?   execRes | setCompleted?
  //           N                 nil   |      -       async, do nothing
  //           Y                 nil   |      -       sync, notify step
  //           N                  N    |      Y       sync, already completed, notify step
  //           Y                  N    |      -       error
  //           N                  Y    |      -       async, do nothing
  //           Y                  Y    |      -       sync, notify step
  BOOL f = [executionResult boolValue];
  if (!notifyCompletionCalled && !executionResult)
    return;
  if (notifyCompletionCalled && !executionResult)
    f = YES;
  if (!notifyCompletionCalled && !f)
    completed = YES;
  if (notifyCompletionCalled && !f)
    NSAssert1(NO, @"%@ - notifyCompletion called, but method returned NO", step);
  if (!notifyCompletionCalled && f)
    return;
  [step notifyTokenCompletion:self];
}


@end
