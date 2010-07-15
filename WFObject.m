//
//  WFObject.m
//  Workflow
//
//  Created by jlopez on 7/13/10.
//  Copyright 2010 JLA. All rights reserved.
//
#import "WFObject.h"

#import <objc/runtime.h>

#define debug(x)  NSLog x

static NSThread *asyncThread;

@interface WFObject ()

@property (nonatomic, assign) BOOL enabled;

+ (NSArray *)introspect;
+ (NSThread *)asyncThread;

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


+ (NSThread *)asyncThread {
  @synchronized ([WFObject class]) {
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

@interface WFToken ()
@end

@implementation WFToken

@synthesize step;
@synthesize completionBlock;
@synthesize errors;


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


- (void)associateWithObject:(id)obj {
  @synchronized (tokenAssociations) {
    [tokenAssociations setObject:self forKey:[NSValue valueWithPointer:obj]];
  }
}


- (id)initWithStep:(WFStep *)s {
  if (self = [super init]) {
    step = [s retain];
  }
  return self;
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


- (void)execute {
  NSAssert(NO, @"[JLWorkflowToken execute] pure virtual function");
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

@interface WFSyncToken ()
@end

@implementation WFSyncToken


- (void)execute {
  dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
    [step performSyncStepWithToken:self];
    NSAssert(completed, @"Sync step %@ failed to notify completion", step);
    [step notifyTokenCompletion:self];
  });
}


@end

@interface WFAsyncToken ()
@end

@implementation WFAsyncToken


- (void)execute {
  // [step performAsyncStepWithToken:self] on asynThread
  [step performSelector:@selector(performAsyncStepWithToken:) onThread:[WFObject asyncThread] withObject:self waitUntilDone:NO];
}


@end

@implementation WFStepMetadata

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
    statusSelector = NSSelectorFromString([NSString stringWithFormat:@"mayRun%@Step", name]);
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


- (BOOL)isTokenValid:(WFToken *)token {
  return runningToken == token;
}


- (void)performSyncStepWithToken:(WFSyncToken *)token {
  debug((@"%@ - %@: Running", item, metadata.name));
  [item performSelector:metadata.syncSelector withObject:token];
}


- (void)performAsyncStepWithToken:(WFAsyncToken *)token {
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