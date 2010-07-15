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

@implementation WFToken


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
  debug((@"[%p dealloc]", self));
  [WFToken disassociateToken:self];
  [errors release];
  [completionBlock release];
  [step release];
  [super dealloc];
}


- (BOOL)isValid {
  return [step isTokenValid:self];
}


- (float)progress {
  return self.valid ? step.progress : 0;
}


- (void)setProgress:(float)progress {
  if (self.valid)
    step.progress = progress;
}


- (void)notifyCompletion:(void (^)())block errors:(NSArray *)err {
  NSAssert(!completed, @"notifyCompletion: called on already completed token");
  completed = YES;
  if (!self.valid)
    return;
  completionBlock = [block copy];
  errors = [err retain];
  NSAssert(completionBlock || [errors count], @"One of completionBlock or errors should be specified");
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


- (WFStep *)step {
  return step;
}


- (void(^)())completionBlock {
  return completionBlock;
}


- (NSArray *)errors {
  return errors;
}


- (void)setErrors:(NSArray *)err {
  if (err == errors)
    return;

  [errors release];
  errors = [err retain];
}


- (void)execute {
  NSAssert(NO, @"[JLWorkflowToken execute] pure virtual function");
}


- (id)initWithStep:(WFStep *)s {
  if (self = [super init]) {
    step = [s retain];
  }
  return self;
}


@end