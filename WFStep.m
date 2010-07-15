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
  if (metadata.syncSelector)
    runningToken = [[WFSyncToken alloc] initWithStep:self];
  else
    runningToken = [[WFAsyncToken alloc] initWithStep:self];
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


- (void)performSyncStepWithToken:(WFToken *)token {
  debug((@"%@ - %@: Running", item, metadata.name));
  [item performSelector:metadata.syncSelector withObject:token];
}


- (void)performAsyncStepWithToken:(WFToken *)token {
  debug((@"%@ - %@: Running asynchronously", item, metadata.name));
  [item performSelector:metadata.asyncSelector withObject:token];
}


- (void)notifyTokenCompletion:(WFToken *)token {
  [self performSelectorOnMainThread:@selector(doNotifyTokenCompletion:) withObject:token waitUntilDone:NO];
}


- (void)doNotifyTokenCompletion:(WFToken *)token {
  if (!token.valid)
    return;

  NSAssert2(!completed, @"Called %@ on already completed step %@", NSStringFromSelector(_cmd), self);
  self.errors = [token.errors count] ? token.errors : nil;
  if (!self.failed) {
    token.completionBlock();
    progress = 1;
    completed = YES;
  }
  else
    progress = 0;

  debug((@"%@ - %@: Completed %@", item, metadata.name, self.failed ? @"unsuccessfully" : @"successfully"));
  [self releaseToken];
  [item poke];
}


- (NSString *)description {
  return metadata.name;
}


@end
