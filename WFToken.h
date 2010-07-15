//
//  WFToken.h
//  Workflow
//
//  Created by jlopez on 7/14/10.
//  Copyright 2010 JLA. All rights reserved.
//

@class WFStep;

@interface WFToken : NSObject {
@protected
  WFStep *step;
  BOOL notifyCompletionCalled;
  BOOL completed;
  BOOL executing;
  BOOL executed;
  void (^completionBlock)();
  NSArray *errors;
}

@property (nonatomic, readonly, getter = isValid) BOOL valid;
@property (nonatomic, assign) float progress;

+ (id)associatedTokenForObject:(id)obj;

- (void)associateWithObject:(id)obj;
- (void)notifyCompletion:(void(^)())instanceUpdateBlock;
- (void)notifyFailure:(NSError *)error;
- (void)notifyMultipleFailure:(NSArray *)error;

@end
