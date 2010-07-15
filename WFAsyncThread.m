//
//  WFAsyncThread.m
//  Workflow
//
//  Created by jlopez on 7/14/10.
//  Copyright 2010 JLA. All rights reserved.
//
#import "WFAsyncThread.h"


@implementation WFAsyncThread


static WFAsyncThread *sharedInstance = nil;
+ (WFAsyncThread *)sharedInstance {
  if (sharedInstance == nil) {
    sharedInstance = [[super allocWithZone:NULL] init];
  }
  return sharedInstance;
}

+ (id)allocWithZone:(NSZone *)zone {
  return [[self sharedInstance] retain];
}

- (id)copyWithZone:(NSZone *)zone {
  return self;
}

- (id)retain {
  return self;
}

- (NSUInteger)retainCount {
  return NSUIntegerMax;  //denotes an object that cannot be released
}

- (void)release {
  //do nothing
}

- (id)autorelease {
  return self;
}


- (void)dealloc {
  [super dealloc];
}


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
  NSAutoreleasePool *outerPool = [NSAutoreleasePool new];
  @try {
    while (running) {
      NSAutoreleasePool *pool = [NSAutoreleasePool new];
      @try {
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:600]];
      } @finally {
        [pool release];
      }
    }
  } @catch (NSException *exception) {
    NSLog(@"Exception caught: %@ %@", exception, [exception userInfo]);
  } @finally {
    NSLog(@"Exiting AsyncThread");
    [outerPool release];
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
