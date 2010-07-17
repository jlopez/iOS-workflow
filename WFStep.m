//
//  WFStep.m
//  Workflow
//
//  Created by jlopez on 7/14/10.
//  Copyright 2010 JLA. All rights reserved.
//
#import "WFStep.h"

#import "WFObject.h"
#import "WFStepMetadata.h"
#import "WFSyncToken.h"
#import "WFAsyncToken.h"
#import "WorkflowPrivate.h"


@interface WFStep ()

- (void)initialize;
- (void)releaseToken;

@end

@implementation WFStep

@synthesize item;
@synthesize progress;
@synthesize completed;
@synthesize errors;

+ (id)stepForItem:(WFObject *)item metadata:(WFStepMetadata *)metadata {
  return [[[self alloc] initForItem:item metadata:metadata] autorelease];
}


- (id)initForItem:(WFObject *)item_ metadata:(WFStepMetadata *)metadata_ {
  if (self = [super init]) {
    item = item_;
    metadata = metadata_;
    [self initialize];
  }
  return self;
}


- (void)initialize {
  NSMethodSignature *signature = [item methodSignatureForSelector:metadata.statusSelector];
  statusInvocation = [[NSInvocation invocationWithMethodSignature:signature] retain];
  [statusInvocation setTarget:item];
  [statusInvocation setSelector:metadata.statusSelector];
}


- (void)dealloc {
  [self releaseToken];
  [errors release];
  [statusInvocation release];
  [super dealloc];
}


- (void)performInBackground {
  NSAssert1(!self.running, @"Step %d is already running", self);
  NSAssert1(!completed, @"Step %d is already completed", self);
  runningToken = [[metadata.tokenClass alloc] initWithStep:self];
  [runningToken execute];
}


- (float)weightedProgress {
  return progress * metadata.progressWeight;
}


- (BOOL)mayRun {
  BOOL returnValue;
  [statusInvocation invoke];
  [statusInvocation getReturnValue:&returnValue];
  return returnValue;
}


- (void)cancel {
  [self releaseToken];
}


- (void)releaseToken {
  [WFToken disassociateToken:runningToken];
  [runningToken release];
  runningToken = nil;
}


- (void)reset {
  if (self.running)
    return;

  completed = NO;
  [errors release];
  errors = nil;
}


- (BOOL)isRunning {
  return runningToken != nil;
}


- (BOOL)isFailed {
  return [errors count];
}


- (BOOL)isTokenValid:(WFToken *)token {
  return runningToken == token;
}


- (NSNumber *)performStepWithToken:(WFToken *)token {
  debug((@"%@ - %@: Running", item, metadata.name));
  // Important - Note how runInvocation is created here every time.
  // Why isn't it cached by WFStep? Not how a cached NSInvocation
  // may not be used from multiple threads, since each instance will
  // have a different token as arg2. Would that actually happen?
  // Previously we thought this was unlikely, but it's actually
  // quite common for synchronous steps. The sync step can take a
  // while to complete. If during this time the step is canceled,
  // and then the WFObject is restarted, the new token
  // will attempt execution while the previous one is still holding
  // the NSInvocation lock. This will cause the new execution to wait
  // until the previous invalid execution returns.
  // The correct implementation requires per token NSInvocation...
  NSMethodSignature *signature = [item methodSignatureForSelector:metadata.runSelector];
  BOOL runReturnsBoolean = !strcmp([signature methodReturnType], "c");
  NSInvocation *runInvocation = [NSInvocation invocationWithMethodSignature:signature];
  [runInvocation setTarget:item];
  [runInvocation setSelector:metadata.runSelector];
  [runInvocation setArgument:&token atIndex:2];
  [runInvocation invoke];
  if (!runReturnsBoolean)
    return nil;
  BOOL boolean;
  [runInvocation getReturnValue:&boolean];
  return [NSNumber numberWithBool:boolean];
}


- (void)notifyTokenCompletion:(WFToken *)token {
  [self performSelectorOnMainThread:@selector(doNotifyTokenCompletion:) withObject:token waitUntilDone:NO];
}


- (void)doNotifyTokenCompletion:(WFToken *)token {
  if (!token.valid) {
    // Last chance to ignore token, we're on main thread now
    // This should be rare (token got canceled while awaiting
    // scheduling on main thread). Normally, invalid tokens are
    // discarded during -[WFToken execute]
    debug((@"%@ - %@: Last chance: Ignoring completion on canceled token", item, metadata.name));
    return;
  }

  NSAssert2(!completed, @"Called %@ on already completed step %@", NSStringFromSelector(_cmd), self);
  [token runCompletionBlock];
  completed = token.completed;
  self.errors = token.errors;
  progress = token.progress;

  debug((@"%@ - %@: Completed %@", item, metadata.name, self.failed ? @"unsuccessfully" : @"successfully"));
  [self releaseToken];
  [item poke];
}


- (NSString *)description {
  return metadata.name;
}


@end
