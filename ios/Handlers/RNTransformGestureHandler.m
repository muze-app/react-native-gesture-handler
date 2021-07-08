#import "RNTransformGestureHandler.h"
#import "RNGestureHandler-Swift.h"
#import <React/RCTConvert.h>

@implementation RNTransformGestureHandler {
    CGAffineTransform accumulatedTransform;
    CGFloat maxYTranslation;
    bool didSetInitialTransform;
}

- (instancetype)initWithTag:(NSNumber *)tag
{
  if ((self = [super initWithTag:tag])) {
      _recognizer = [[NaturalTransformGestureRecognizer alloc] initWithTarget:self action:@selector(handleGesture:)];
      accumulatedTransform = CGAffineTransformIdentity;
      maxYTranslation = CGFLOAT_MAX;
      didSetInitialTransform = false;
  }
  return self;
}

- (void)handleGesture:(NaturalTransformGestureRecognizer *)recognizer {
    [super handleGesture:recognizer];
    
    CGAffineTransform nextAccumulatedTransform =
        CGAffineTransformConcat(accumulatedTransform,
                                recognizer.transformFromLastChange);
    
    if (nextAccumulatedTransform.ty > maxYTranslation) {
        nextAccumulatedTransform.ty = maxYTranslation;
    }
    accumulatedTransform = nextAccumulatedTransform;
}

- (void)configure:(NSDictionary *)config
{
    [super configure:config];
    id prop = config[@"initialTransform"];
    if (prop != nil && !didSetInitialTransform) {
        accumulatedTransform = [RCTConvert CGAffineTransform:prop];
        didSetInitialTransform = true;
    }
    
    prop = config[@"maxYTranslation"];
    if (prop != nil) {
        maxYTranslation = [RCTConvert CGFloat:prop];
    }
}

- (RNGestureHandlerEventExtraData *)eventExtraData:(NaturalTransformGestureRecognizer *)recognizer{
    return [[RNGestureHandlerEventExtraData alloc] initWithData:@{
        @"transform": self.accumulatedTransformAsDictionary
    }];
}

- (NSDictionary *)accumulatedTransformAsDictionary {
    CGAffineTransform xf = accumulatedTransform;
    return @{
        @"a": [NSNumber numberWithDouble:xf.a],
        @"b": [NSNumber numberWithDouble:xf.b],
        @"c": [NSNumber numberWithDouble:xf.c],
        @"d": [NSNumber numberWithDouble:xf.d],
        @"tx": [NSNumber numberWithDouble:xf.tx],
        @"ty": [NSNumber numberWithDouble:xf.ty],
    };
}

@end
