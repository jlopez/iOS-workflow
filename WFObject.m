//
//  WFObject.m
//  Workflow
//
//  Created by jlopez on 7/13/10.
//  Copyright 2010 JLA. All rights reserved.
//
#import "WFObject.h"

#import "WFStep.h"
#import "WFStepMetadata.h"

#import <objc/runtime.h>

@interface WFObject ()

@property (nonatomic, assign) BOOL enabled;

+ (NSArray *)introspect;

- (void)initialize;

@end


@implementation WFObject

@synthesize enabled;


static NSMutableDictionary *dictionary = nil;
+ (NSArray *)metadata {
  @synchronized ([WFObject class]) {
    NSString *key = NSStringFromClass(self);
    NSArray *metadata = [dictionary objectForKey:key];
    if (!metadata) {
      metadata = [self introspect];
      if (dictionary == nil)
        dictionary = [[NSMutableDictionary dictionaryWithObject:metadata forKey:key] retain];
      else
        [dictionary setObject:[NSValue valueWithPointer:metadata] forKey:key];
    }
    return metadata;
  }
}


+ (NSArray *)introspect {
  NSAssert(self != [WFObject class], @"JLWorkflowItem must be subclassed");

  NSMutableArray *metadata = [NSMutableArray array];
  float totalWeight = 0;
  unsigned int methodCount;
  Method *methods = class_copyMethodList(self, &methodCount);
  for (int i = 0; i < methodCount; ++i) {
    SEL sel = method_getName(methods[i]);
    NSString *name = NSStringFromSelector(sel);
    if ([name length] <= 6 + 4 || ![name hasPrefix:@"mayRun"] || ![name hasSuffix:@"Step"])
      continue;
    NSString *stepName = [name substringWithRange:NSMakeRange(6, [name length] - 4 - 6)];
    WFStepMetadata *stepMetadata = [WFStepMetadata metadataForClass:self name:(NSString *)stepName];
    [metadata addObject:stepMetadata];
    totalWeight += stepMetadata.progressWeight;
  }
  free(methods);

  NSAssert1([metadata count], @"Class %@ does not implement any method matching mayRun<N>Step", self);
  NSAssert(totalWeight > 0, @"Invalid progress weights: Sum(weight) == 0");

  for (WFStepMetadata *step in metadata)
    [step normalizeWeightUsingFactor:totalWeight];

  return [NSArray arrayWithArray:metadata];
}


- (id)init {
  if (self = [super init]) {
    [self initialize];
  }
  return self;
}


- (id)initWithCoder:(NSCoder *)decoder {
  if (self = [super init]) {
    [self initialize];
    enabled = [decoder decodeBoolForKey:@"SKEnabled"];
    [self poke];
  }
  return self;
}


- (void)initialize {
  metadata = [[self class] metadata];
  NSMutableArray *accum = [NSMutableArray arrayWithCapacity:[metadata count]];
  for (WFStepMetadata *stepMetadata in metadata)
    [accum addObject:[WFStep stepForItem:self metadata:stepMetadata]];
  steps = [[NSArray alloc] initWithArray:accum];
}


- (void)encodeWithCoder:(NSCoder *)coder {
  [coder encodeBool:enabled forKey:@"SKEnabled"];
}


- (void)dealloc {
  [steps release];
  [super dealloc];
}


- (void)start {
  NSAssert2([NSThread isMainThread], @"[%@ %@] may only be called on main thread", [self class], NSStringFromSelector(_cmd));
  self.enabled = YES;
  [self poke];
}


- (void)poke {
  NSAssert2([NSThread isMainThread], @"[%@ %@] may only be called on main thread", [self class], NSStringFromSelector(_cmd));
  if (!enabled)
    return;

  for (WFStep *step in steps) {
    if (step.running)
      continue;
    if (step.completed)
      continue;
    if (![step mayRun])
      continue;
    [step performInBackground];
  }
}


- (void)stop {
  NSAssert2([NSThread isMainThread], @"[%@ %@] may only be called on main thread", [self class], NSStringFromSelector(_cmd));
  if (!enabled)
    return;

  self.enabled = NO;
  for (WFStep *step in steps)
    [step cancel];
}


- (void)reset {
  NSAssert2([NSThread isMainThread], @"[%@ %@] may only be called on main thread", [self class], NSStringFromSelector(_cmd));
  NSAssert(!enabled, @"Can't call reset on running item");

  for (WFStep *step in steps)
    [step reset];
}


- (float)overallProgress {
  float overallProgress = 0;
  for (WFStep *step in steps)
    overallProgress += step.weightedProgress;
  return overallProgress;
}


//- (float)progressForStep:(int)step;
//- (BOOL)isStepRunning:(int)step;
//- (BOOL)isStepCompleted:(int)step;
//- (BOOL)isStepFailed:(int)step;
//- (NSArray *)errorsForStep:(int)step;
//
//- (float)progressForStep:(int)step {
//  return [[steps objectAtIndex:step] progress];
//}
//
//
//- (void)setProgress:(float)progress forStep:(int)step {
//  [[steps objectAtIndex:step] setProgress:progress];
//}
//
//
//- (BOOL)isStepRunning:(int)step {
//  return [[steps objectAtIndex:step] isRunning];
//}
//
//
//- (BOOL)isStepCompleted:(int)step {
//  return [[steps objectAtIndex:step] status] == JLWorkflowStepStatusCompleted;
//}
//
//
//- (BOOL)isStepFailed:(int)step {
//  return [[steps objectAtIndex:step] isFailed];
//}
//
//
//- (NSArray *)errorsForStep:(int)step {
//  return [[steps objectAtIndex:step] errors];
//}
//
//
- (NSArray *)errors {
  NSMutableArray *accum = nil;
  for (WFStep *step in steps) {
    if (!step.failed)
      continue;
    if (accum == nil)
      accum = [NSMutableArray arrayWithArray:step.errors];
    else
      [accum addObjectsFromArray:step.errors];
  }
  return accum;
}


- (int)totalSteps {
  return [metadata count];
}


- (BOOL)running {
  for (WFStep *step in steps)
    if (step.running)
      return YES;
  return NO;
}


- (BOOL)completed {
  for (WFStep *step in steps)
    if (step.completed)
      return YES;
  return NO;
}


- (BOOL)failed {
  for (WFStep *step in steps)
    if (step.failed)
      return YES;
  return NO;
}


@end
