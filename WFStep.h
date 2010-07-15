//
//  WFStep.h
//  Workflow
//
//  Created by jlopez on 7/14/10.
//  Copyright 2010 JLA. All rights reserved.
//
#import <Foundation/Foundation.h>

@class WFObject;
@class WFStepMetadata;
@class WFToken;

@interface WFStep : NSObject {
@private
  WFObject *item;
  WFStepMetadata *metadata;
  NSInvocation *statusInvocation;
  WFToken *runningToken;
  float progress;
  BOOL completed;
  NSArray *errors;
}

@property (nonatomic, readonly, getter=isRunning) BOOL running;
@property (nonatomic, readonly) BOOL completed;
@property (nonatomic, assign) float progress;
@property (nonatomic, readonly) float weightedProgress;
@property (nonatomic, retain) NSArray *errors;
@property (nonatomic, readonly, getter=isFailed) BOOL failed;

+ (id)stepForItem:(WFObject *)item metadata:(WFStepMetadata *)metadata;

- (id)initForItem:(WFObject *)item metadata:(WFStepMetadata *)metadata;
- (void)reset;
- (void)cancel;
- (void)performInBackground;

- (BOOL)isTokenValid:(WFToken *)token;

- (BOOL)mayRun;
- (void)performSyncStepWithToken:(WFToken *)token;
- (void)performAsyncStepWithToken:(WFToken *)token;
- (void)notifyTokenCompletion:(WFToken *)token;

@end
