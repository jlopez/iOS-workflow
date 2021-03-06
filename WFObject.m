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
@property (nonatomic, assign) BOOL running;

+ (NSArray *)introspect;

- (void)initialize;

@end


@implementation WFObject

@synthesize enabled;
@synthesize running;


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
    NSDictionary *stepDict = [decoder decodeObjectForKey:@"SKSteps"];
    for (WFStep *step in steps) {
      id obj = [stepDict objectForKey:step.name];
      if (obj)
        [step decodeFromObject:obj];
    }
    // Allow subclass to decode before poking ourselves
    [self performSelector:@selector(poke) withObject:nil afterDelay:0];
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
  NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithCapacity:[steps count]];
  for (WFStep *step in steps)
    [dict setObject:[step encodeIntoObject] forKey:step.name];
  [coder encodeObject:dict forKey:@"SKSteps"];
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

  BOOL newRunning = NO;
  for (WFStep *step in steps) {
    if (step.running) {
      newRunning = YES;
      continue;
    }
    if (step.completed || step.failed)
      continue;
    if (![step mayRun])
      continue;
    [step performInBackground];
    newRunning = YES;
  }

  // Update running status (and KVObservers)
  if (newRunning != running)
    self.running = newRunning;
}


- (void)stop {
  NSAssert2([NSThread isMainThread], @"[%@ %@] may only be called on main thread", [self class], NSStringFromSelector(_cmd));
  if (!enabled)
    return;

  self.enabled = NO;
  for (WFStep *step in steps)
    [step cancel];

  self.running = NO;
}


- (void)reset {
  NSAssert2([NSThread isMainThread], @"[%@ %@] may only be called on main thread", [self class], NSStringFromSelector(_cmd));

  for (WFStep *step in steps)
    [step reset];
  [self poke];
}


- (float)overallProgress {
  float overallProgress = 0;
  for (WFStep *step in steps)
    overallProgress += step.weightedProgress;
  return overallProgress;
}


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


- (BOOL)isCompleted {
  for (WFStep *step in steps)
    if (step.completed)
      return YES;
  return NO;
}


- (BOOL)isFailed {
  for (WFStep *step in steps)
    if (step.failed)
      return YES;
  return NO;
}


@end
