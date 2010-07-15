//
//  WFStepMetadata.h
//  Workflow
//
//  Created by jlopez on 7/14/10.
//  Copyright 2010 JLA. All rights reserved.
//
#import <Foundation/Foundation.h>


@interface WFStepMetadata : NSObject {
  NSString *name;
  SEL statusSelector;
  SEL syncSelector;
  SEL asyncSelector;
  float progressWeight;
}

@property (nonatomic, readonly) NSString *name;
@property (nonatomic, readonly) SEL statusSelector;
@property (nonatomic, readonly) SEL syncSelector;
@property (nonatomic, readonly) SEL asyncSelector;
@property (nonatomic, readonly) float progressWeight;

+ (id)metadataForClass:(Class)cls name:(NSString *)stepName;

- (id)initForClass:(Class)cls name:(NSString *)stepName;
- (void)normalizeWeightUsingFactor:(float)factor;

@end
