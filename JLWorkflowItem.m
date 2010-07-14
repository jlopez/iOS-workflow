//
//  JLWorkflowItem.m
//  Workflow
//
//  Created by jlopez on 7/13/10.
//  Copyright 2010 JLA. All rights reserved.
//
#import "JLWorkflowItem.h"

#import <objc/runtime.h>

#define debug(x)  NSLog x

static NSThread *asyncThread;

@interface JLWorkflowItem ()

@property (nonatomic, assign) BOOL enabled;

+ (NSArray *)introspect;
+ (NSThread *)asyncThread;

- (void)initialize;

@end


@implementation JLWorkflowItem

@synthesize enabled;


static NSMutableDictionary *dictionary = nil;
+ (NSArray *)metadata {
  @synchronized ([JLWorkflowItem class]) {
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
  NSAssert(self != [JLWorkflowItem class], @"JLWorkflowItem must be subclassed");

  NSMutableArray *metadata = [NSMutableArray array];
  float totalWeight = 0;
  unsigned int methodCount;
  Method *methods = class_copyMethodList(self, &methodCount);
  for (int i = 0; i < methodCount; ++i) {
    SEL sel = method_getName(methods[i]);
    NSString *name = NSStringFromSelector(sel);
    if ([name length] <= 9 + 4 || ![name hasPrefix:@"statusFor"] || ![name hasSuffix:@"Step"])
      continue;
    NSString *stepName = [name substringWithRange:NSMakeRange(9, [name length] - 4 - 9)];
    JLWorkflowStepMetadata *stepMetadata = [JLWorkflowStepMetadata metadataForClass:self name:(NSString *)stepName];
    [metadata addObject:stepMetadata];
    totalWeight += stepMetadata.progressWeight;
  }
  free(methods);

  NSAssert1([metadata count], @"Class %@ does not implement any method matching statusFor<N>Step", self);
  NSAssert(totalWeight > 0, @"Invalid progress weights: Sum(weight) == 0");

  for (JLWorkflowStepMetadata *step in metadata)
    [step normalizeWeightUsingFactor:totalWeight];

  return [NSArray arrayWithArray:metadata];
}


+ (NSThread *)asyncThread {
  @synchronized ([JLWorkflowItem class]) {
    if (!asyncThread)
      asyncThread = [JLWorkflowAsyncThread new];
    return asyncThread;
  }
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
  for (JLWorkflowStepMetadata *stepMetadata in metadata)
    [accum addObject:[JLWorkflowStep stepForItem:self metadata:stepMetadata]];
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

  for (JLWorkflowStep *step in steps) {
    if (step.running)
      continue;
    if ([step status] != JLWorkflowStepStatusCanRun)
      continue;
    [step performInBackground];
  }
}


- (void)stop {
  NSAssert2([NSThread isMainThread], @"[%@ %@] may only be called on main thread", [self class], NSStringFromSelector(_cmd));
  if (!enabled)
    return;

  self.enabled = NO;
  for (JLWorkflowStep *step in steps)
    [step cancel];
}


- (void)reset {
  NSAssert2([NSThread isMainThread], @"[%@ %@] may only be called on main thread", [self class], NSStringFromSelector(_cmd));
  NSAssert(!enabled, @"Can't call reset on running item");

  for (JLWorkflowStep *step in steps)
    [step reset];
}


- (float)overallProgress {
  float overallProgress = 0;
  for (JLWorkflowStep *step in steps)
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
  for (JLWorkflowStep *step in steps) {
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
  for (JLWorkflowStep *step in steps)
    if (step.running)
      return YES;
  return NO;
}


- (BOOL)completed {
  for (JLWorkflowStep *step in steps)
    if ([step status] == JLWorkflowStepStatusCompleted)
      return YES;
  return NO;
}


- (BOOL)failed {
  for (JLWorkflowStep *step in steps)
    if (step.failed)
      return YES;
  return NO;
}


@end

@interface JLWorkflowToken ()
@end

@implementation JLWorkflowToken

@synthesize step;
@synthesize errors;


static NSMutableDictionary *tokenAssociations = nil;
+ (void)initialize {
  if (self == [JLWorkflowToken class])
    tokenAssociations = [NSMutableDictionary new];
}


+ (id)associatedTokenForObject:(id)obj {
  @synchronized (tokenAssociations) {
    return [tokenAssociations objectForKey:[NSValue valueWithPointer:obj]];
  }
}


+ (void)disassociateToken:(JLWorkflowToken *)token {
  @synchronized (tokenAssociations) {
    NSMutableArray *keys = [NSMutableArray array];
    for (NSValue *key in tokenAssociations) {
      if ([tokenAssociations objectForKey:key] == token)
        [keys addObject:key];
    }
    [tokenAssociations removeObjectsForKeys:keys];
  }
}


- (void)associateWithObject:(id)obj {
  @synchronized (tokenAssociations) {
    [tokenAssociations setObject:self forKey:[NSValue valueWithPointer:obj]];
  }
}


- (id)initWithStep:(JLWorkflowStep *)s {
  if (self = [super init]) {
    step = [s retain];
  }
  return self;
}


- (void)dealloc {
  debug((@"[%p dealloc]", self));
  [JLWorkflowToken disassociateToken:self];
  [step release];
  [errors release];
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


- (void)execute {
  NSAssert(NO, @"[JLWorkflowToken execute] pure virtual function");
}


@end

@interface JLWorkflowSyncToken ()
@end

@implementation JLWorkflowSyncToken


- (void)execute {
  dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
    self.errors = [step performSyncStepWithToken:self];
    [step notifyTokenCompletion:self];
  });
}


@end

@interface JLWorkflowAsyncToken ()
@end

@implementation JLWorkflowAsyncToken


- (void)execute {
  // [step performAsyncStepWithToken:self] on asynThread
  [step performSelector:@selector(performAsyncStepWithToken:) onThread:[JLWorkflowItem asyncThread] withObject:self waitUntilDone:NO];
}


- (void)completeAsynchronousStep {
  [self completeAsynchronousStepWithErrors:nil];
}


- (void)completeAsynchronousStepWithError:(NSError *)error {
  if (error)
    [self completeAsynchronousStepWithErrors:[NSArray arrayWithObject:error]];
  else
    [self completeAsynchronousStepWithErrors:nil];
}


- (void)completeAsynchronousStepWithErrors:(NSArray *)errors_ {
  NSAssert(!completed, @"completeAsynchronousStepWithErrors called on already completed token");
  completed = YES;
  self.errors = errors_;
  [step notifyTokenCompletion:self];
}


@end

@implementation JLWorkflowStepMetadata

@synthesize name;
@synthesize statusSelector;
@synthesize syncSelector;
@synthesize asyncSelector;
@synthesize progressWeight;


+ (id)metadataForClass:(Class)cls name:(NSString *)stepName {
  return [[[self alloc] initForClass:cls name:stepName] autorelease];
}


- (id)initForClass:(Class)cls name:(NSString *)stepName {
  if (self = [super init]) {
    name = [stepName copy];
    statusSelector = NSSelectorFromString([NSString stringWithFormat:@"statusFor%@Step", name]);
    NSString *syncName = [NSString stringWithFormat:@"perform%@Step:", name];
    NSString *asyncName = [NSString stringWithFormat:@"perform%@StepAsynchronously:", name];
    syncSelector = NSSelectorFromString(syncName);
    if (![cls instancesRespondToSelector:syncSelector])
      syncSelector = nil;
    asyncSelector = NSSelectorFromString(asyncName);
    if (![cls instancesRespondToSelector:asyncSelector])
      asyncSelector = nil;
    SEL weightSelector = NSSelectorFromString([NSString stringWithFormat:@"progressWeightFor%@Step", name]);
    NSAssert(![cls instancesRespondToSelector:weightSelector], @"[%@ %@] declared as instance method", cls, NSStringFromSelector(weightSelector));
    progressWeight = 1;
    if ([cls respondsToSelector:weightSelector]) {
      NSMethodSignature *signature = [cls methodSignatureForSelector:weightSelector];
      NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];
      [invocation setTarget:cls];
      [invocation setSelector:weightSelector];
      [invocation invoke];
      [invocation getReturnValue:&progressWeight];
    }
    NSAssert3(syncSelector || asyncSelector, @"Class %@ should implement one of %@ or %@", cls, syncName, asyncName);
    NSAssert3(!syncSelector || !asyncSelector, @"Class %@ should implement only one of %@ and %@", cls, syncName, asyncName);
  }
  return self;
}


- (void)normalizeWeightUsingFactor:(float)factor {
  progressWeight /= factor;
}


- (void)dealloc {
  [name release];
  [super dealloc];
}


@end

@interface JLWorkflowStep ()

- (void)initialize;
- (void)releaseToken;

@end

@implementation JLWorkflowStep

@synthesize progress;
@synthesize errors;

+ (id)stepForItem:(JLWorkflowItem *)item metadata:(JLWorkflowStepMetadata *)metadata {
  return [[[self alloc] initForItem:item metadata:metadata] autorelease];
}


- (id)initForItem:(JLWorkflowItem *)item_ metadata:(JLWorkflowStepMetadata *)metadata_ {
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
  if (metadata.syncSelector)
    runningToken = [[JLWorkflowSyncToken alloc] initWithStep:self];
  else
    runningToken = [[JLWorkflowAsyncToken alloc] initWithStep:self];
  [runningToken execute];
}


- (float)weightedProgress {
  return progress * metadata.progressWeight;
}


- (JLWorkflowStepStatus)status {
  JLWorkflowStepStatus returnValue;
  [statusInvocation invoke];
  [statusInvocation getReturnValue:&returnValue];
  return returnValue;
}


- (void)cancel {
  [self releaseToken];
}


- (void)releaseToken {
  [JLWorkflowToken disassociateToken:runningToken];
  [runningToken release];
  runningToken = nil;
}


- (void)reset {
  NSAssert1(!self.running, @"Can't reset running step %@", self);
  [errors release];
  errors = nil;
}


- (BOOL)isRunning {
  return runningToken != nil;
}


- (BOOL)isFailed {
  return [errors count];
}


- (BOOL)isTokenValid:(JLWorkflowToken *)token {
  return runningToken == token;
}


- (NSArray *)performSyncStepWithToken:(JLWorkflowSyncToken *)token {
  debug((@"%@ - %@: Running", item, metadata.name));
  return [item performSelector:metadata.syncSelector withObject:token];
}


- (void)performAsyncStepWithToken:(JLWorkflowAsyncToken *)token {
  debug((@"%@ - %@: Running asynchronously", item, metadata.name));
  [item performSelector:metadata.asyncSelector withObject:token];
}


- (void)notifyTokenCompletion:(JLWorkflowToken *)token {
  [self performSelectorOnMainThread:@selector(doNotifyTokenCompletion:) withObject:token waitUntilDone:NO];
}


- (void)doNotifyTokenCompletion:(JLWorkflowToken *)token {
  if (![self isTokenValid:token])
    return;

  errors = [token.errors retain];
  debug((@"%@ - %@: Completed %@", item, metadata.name, self.failed ? @"unsuccessfully" : @"successfully"));
  progress = [self status] == JLWorkflowStepStatusCompleted ? 1.0 : 0.0;
  [self releaseToken];
  [item poke];
}


@end

@implementation JLWorkflowAsyncThread


- (id)init {
  if (self = [super init]) {
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationWillTerminate:) name:UIApplicationWillTerminateNotification object:nil];
    [self setName:@"WorkflowAsyncThread"];
    running = YES;
    [self start];
  }
  return self;
}


- (void)main {
  NSAutoreleasePool *pool = [NSAutoreleasePool new];
  @try {
    while (running) {
      [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:600]];
    }
  } @catch (NSException *exception) {
    NSLog(@"Exception caught: %@ %@", exception, [exception userInfo]);
  } @finally {
    NSLog(@"Exiting AsyncThread");
    [pool release];
  }
}


- (void)exitThread {
  NSLog(@"[self exitThread]: Async thread");
  running = NO;
}


- (void)applicationWillTerminate:(id)notification {
  [self performSelector:@selector(exitThread) onThread:self withObject:nil waitUntilDone:YES];
}


@end