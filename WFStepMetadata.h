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
  float progressWeight;
}

@property (nonatomic, readonly) NSString *name;
@property (nonatomic, readonly) SEL statusSelector;
@property (nonatomic, readonly) SEL runSelector;
@property (nonatomic, readonly) Class tokenClass;
@property (nonatomic, readonly) float progressWeight;

+ (id)metadataForClass:(Class)cls name:(NSString *)stepName;

- (id)initForClass:(Class)cls name:(NSString *)stepName;
- (void)normalizeWeightUsingFactor:(float)factor;

@end
