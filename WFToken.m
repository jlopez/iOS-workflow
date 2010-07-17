//
//  WFToken.m
//  Workflow
//
//  Created by jlopez on 7/14/10.
//  Copyright 2010 JLA. All rights reserved.
//
#import "WFObject.h"

#import "WorkflowPrivate.h"
#import "WFStep.h"

@interface WFToken ()

@property (nonatomic, readonly) WFStep *step;
@property (nonatomic, retain) NSArray *errors;
@property (nonatomic, readonly, getter=isCompleted) BOOL completed;
@property (nonatomic, copy) void (^completionBlock)();

@end

@implementation WFToken

@synthesize errors;
@synthesize completionBlock;
@synthesize step;
@synthesize completed;

static NSMutableDictionary *tokenAssociations = nil;
+ (void)initialize {
  if (self == [WFToken class])
    tokenAssociations = [NSMutableDictionary new];
}


+ (id)associatedTokenForObject:(id)obj {
  @synchronized (tokenAssociations) {
    return [tokenAssociations objectForKey:[NSValue valueWithPointer:obj]];
  }
}


- (void)associateWithObject:(id)obj {
  @synchronized (tokenAssociations) {
    [tokenAssociations setObject:self forKey:[NSValue valueWithPointer:obj]];
  }
}


- (void)dealloc {
  [WFToken disassociateToken:self];
  self.errors = nil;
  self.completionBlock = nil;
  [step release];
  [super dealloc];
}


- (BOOL)isValid {
  return [step isTokenValid:self];
}


- (float)progress {
  if (completed)
    return 1;
  if (errors)
    return 0;
  if (self.valid)
    return step.progress;
  return 0;
}


- (void)setProgress:(float)progress {
  NSAssert1(!completed && !errors, @"%@ - Attempted to set progress on already executed token", step);
  if (self.valid)
    step.progress = progress;
}


- (void)setErrors:(NSArray *)err {
  // Custom setter to turn empty arrays into nil
  if ([err count] == 0)
    err = nil;

  if (err == errors)
    return;

  [errors release];
  errors = [err retain];
}


- (void)notifyCompletion:(void (^)())block errors:(NSArray *)err {
  NSAssert1(!notifyCompletionCalled, @"%@ - notifyCompletion called on already completed token", step);
  notifyCompletionCalled = YES;
  if (!self.valid)
    return;
  self.completionBlock = [[block copy] autorelease];
  self.errors = err; // Automatically sets errors to nil if err is an empty array
  completed = completionBlock != nil;
  NSAssert1(completionBlock || errors, @"%@ - Both completionBlock & errors are unset", step);
  NSAssert1(!completionBlock || !errors, @"%@ - Both completionBlock & errors are set", step);

  // executing
  //     N       Asynchronous call, notify step
  //     Y       Synchronous call, do not notify step, sync execute will do
  if (!executing)
    [step notifyTokenCompletion:self];
}


- (void)notifyCompletion:(void(^)())instanceUpdateBlock {
  [self notifyCompletion:instanceUpdateBlock errors:nil];
}


- (void)notifyFailure:(NSError *)error {
  [self notifyCompletion:completionBlock errors:[NSArray arrayWithObject:error]];
}


- (void)notifyMultipleFailure:(NSArray *)errs {
  [self notifyCompletion:completionBlock errors:errs];
}


@end

@implementation WFToken (WFPrivate)


+ (void)disassociateToken:(WFToken *)token {
  @synchronized (tokenAssociations) {
    NSMutableArray *keys = [NSMutableArray array];
    for (NSValue *key in tokenAssociations) {
      if ([tokenAssociations objectForKey:key] == token)
        [keys addObject:key];
    }
    [tokenAssociations removeObjectsForKeys:keys];
  }
}


- (id)initWithStep:(WFStep *)s {
  if (self = [super init]) {
    step = [s retain];
  }
  return self;
}


- (void)execute {
  NSAssert1(!executing && !executed, @"%@ - [WFToken doExecute] called already", step);
  [self scheduleExecution:^{
    NSAssert1(!executing && !executed, @"%@ - [WFToken doExecute] called already", step);
    executing = YES;
    NSNumber *executionResult = [step performStepWithToken:self];
    executing = NO;
    executed = YES;
    NSAssert1(notifyCompletionCalled || (!completionBlock && !errors), @"%@ - notifyCompletion not called, yet completionBlock or errors set", step);
    if (!self.valid) {
      debug((@"%@ - %@: Ignoring completion on canceled token", step.item, step));
      return;
    }

    [self processExecutionResult:executionResult];
  }];
}


- (void)runCompletionBlock {
  NSAssert(errors == nil || completionBlock == nil, @"Token for step %@ has both errors and completionBlock set", step);
  if (completionBlock)
    completionBlock();
  self.completionBlock = nil;
}


- (void)scheduleExecution:(void (^)(void))block {
  NSAssert1(NO, @"%@ - [WFToken scheduleExecution:] pure virtual function", step);
}


- (void)processExecutionResult:(NSNumber *)executionResult {
  NSAssert1(NO, @"%@ - [WFToken processExecutionResult:] pure virtual function", step);
}


@end