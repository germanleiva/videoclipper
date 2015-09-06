//
//  KPCameraButton.m
//  CameraButtonClone
//
//  Created by Eric Mika on 3/27/14.
//  Copyright (c) 2014 Kitschpatrol. All rights reserved.
//

#import "KPCameraButton.h"

@interface KPCameraButton ()

@property (nonatomic, strong) UIColor *videoRecordingColor;
@property (nonatomic, strong) CAShapeLayer *ringElementLayer;
@property (nonatomic, strong) CAShapeLayer *centerElementLayer;
@property (nonatomic, strong) UIBezierPath *notRecordingPath;
@property (nonatomic, strong) UIBezierPath *recordingPath;

@end

@implementation KPCameraButton

- (id)init
{
  // Default size in Camera.app
  return [self initWithFrame:CGRectMake(0, 0, 66, 66)];
}

- (id)initWithFrame:(CGRect)frame
{
  self = [super initWithFrame:frame];
  if (self) {
    [self sharedInit];
  }
  return self;
}

- (id)initWithCoder:(NSCoder *)aDecoder
{
  self = [super initWithCoder:aDecoder];
  if (self) {
    [self sharedInit];
  }
  return self;
}

- (void)sharedInit
{
  _cameraButtonMode = KPCameraButtonModePhoto;

  _videoRecordingColor = [UIColor colorWithRed:245.0 / 255.0 green:51.0 / 255.0 blue:51.0 / 255.0 alpha:1.0];

  // Outer ring layer
  const CGFloat ringLineThickness = (6.0 / 66.0) * CGRectGetWidth(self.bounds);
  const CGRect boundsWithThicknessInset = CGRectInset(self.bounds, ringLineThickness / 2.0, ringLineThickness / 2.0);
  _ringElementLayer = [CAShapeLayer layer];
  _ringElementLayer.path = CGPathCreateWithEllipseInRect(boundsWithThicknessInset, nil);
  //_ringElementLayer.fillColor = nil;
  _ringElementLayer.strokeColor = [UIColor whiteColor].CGColor;
  _ringElementLayer.lineWidth = ringLineThickness;
  [self.layer addSublayer:_ringElementLayer];

  // Center element, non-playing mode (circle)
  const CGFloat circleInset = ringLineThickness + ((2.0 / 66.0) * CGRectGetWidth(self.bounds));
  CGRect circleInsetRect = CGRectInset(self.bounds, circleInset, circleInset);
  const CGFloat cornerRadiusForCircle = CGRectGetWidth(circleInsetRect) * 0.5;
  _notRecordingPath = [self tweenableBezierPathWithRoundedRect:circleInsetRect cornerRadius:cornerRadiusForCircle];

  // Center element, playing mode (round rect)
  const CGFloat roundRectInset = (19.0 / 66.0) * CGRectGetWidth(self.bounds);
  const CGRect roundRectInsetRect = CGRectInset(self.bounds, roundRectInset, roundRectInset);
  const CGFloat cornerRadiusForRoundedRect = CGRectGetWidth(roundRectInsetRect) * (7.0 / 56.0);
  _recordingPath = [self tweenableBezierPathWithRoundedRect:roundRectInsetRect cornerRadius:cornerRadiusForRoundedRect];

  // Center element layer
  _centerElementLayer = [CAShapeLayer layer];
  _centerElementLayer.path = _notRecordingPath.CGPath;
  _centerElementLayer.fillColor = [UIColor whiteColor].CGColor;
  _centerElementLayer.lineWidth = 0.0;
  _centerElementLayer.strokeColor = nil;
  [self.layer addSublayer:_centerElementLayer];

  [self updateCameraButtonMode:_cameraButtonMode animated:NO];
}

- (void)setCameraButtonMode:(KPCameraButtonMode)cameraButtonMode
{
  if (_cameraButtonMode != cameraButtonMode) {
    _cameraButtonMode = cameraButtonMode;
    [self updateCameraButtonMode:self.cameraButtonMode animated:YES];
  }
}

- (void)updateCameraButtonMode:(KPCameraButtonMode)mode animated:(BOOL)animated
{
  switch (mode) {
    case KPCameraButtonModePhoto: {
      // Goes white
      // self.centerElementLayer.fillColor = [UIColor whiteColor].CGColor;
      CABasicAnimation *cameraButtonModeAnimation = [CABasicAnimation animationWithKeyPath:@"fillColor"];
      cameraButtonModeAnimation.toValue = (id)[UIColor whiteColor].CGColor;
      cameraButtonModeAnimation.duration = animated ? 0.5 : 0.0;
      cameraButtonModeAnimation.fillMode = kCAFillModeForwards;
      cameraButtonModeAnimation.removedOnCompletion = NO;
      [self.centerElementLayer addAnimation:cameraButtonModeAnimation forKey:@"KPCameraButtonModePhotoColorAnimation"];

      // Goes round
      CABasicAnimation *morph = [CABasicAnimation animationWithKeyPath:@"path"];
      morph.duration = animated ? 0.25 : 0.0; // Step 1
      morph.toValue = (id)self.notRecordingPath.CGPath;
      morph.fillMode = kCAFillModeForwards;
      morph.removedOnCompletion = NO;
      [self.centerElementLayer addAnimation:morph forKey:@"KPCameraButtonModePhotoShapeAnimation"];

      break;
    }
    case KPCameraButtonModeVideoReady: {
      // Goes red
      CABasicAnimation *cameraButtonModeAnimation = [CABasicAnimation animationWithKeyPath:@"fillColor"];
      cameraButtonModeAnimation.toValue = (id)self.videoRecordingColor.CGColor;
      cameraButtonModeAnimation.duration = animated ? 0.5 : 0.0;
      cameraButtonModeAnimation.fillMode = kCAFillModeForwards;
      cameraButtonModeAnimation.removedOnCompletion = NO;
      [self.centerElementLayer addAnimation:cameraButtonModeAnimation forKey:@"KPCameraButtonModeVideoReadyColorAnimation"];

      // Goes square
      CABasicAnimation *morph = [CABasicAnimation animationWithKeyPath:@"path"];
      morph.duration = animated ? 0.25 : 0.0; // Step 1
      morph.toValue = (id)self.notRecordingPath.CGPath;
      morph.fillMode = kCAFillModeForwards;
      morph.removedOnCompletion = NO;
      [self.centerElementLayer addAnimation:morph forKey:@"KPCameraButtonModeVideoReadyShapeAnimation"];

      break;
    }
    case KPCameraButtonModeVideoRecording: {
      // Goes red
      CABasicAnimation *cameraButtonModeAnimation = [CABasicAnimation animationWithKeyPath:@"fillColor"];
      cameraButtonModeAnimation.toValue = (id)self.videoRecordingColor.CGColor;
      cameraButtonModeAnimation.duration = animated ? 0.5 : 0.0;
      cameraButtonModeAnimation.fillMode = kCAFillModeForwards;
      cameraButtonModeAnimation.removedOnCompletion = NO;
      [self.centerElementLayer addAnimation:cameraButtonModeAnimation forKey:@"KPCameraButtonModeVideoRecordingColorAnimation"];

      // Goes round
      CABasicAnimation *morph = [CABasicAnimation animationWithKeyPath:@"path"];
      morph.duration = animated ? 0.25 : 0.0; // Step 1
      morph.toValue = (id)self.recordingPath.CGPath;
      morph.fillMode = kCAFillModeForwards;
      morph.removedOnCompletion = NO;
      [self.centerElementLayer addAnimation:morph forKey:@"KPCameraButtonModeVideoRecordingShapeAnimation"];

      break;
    }
    default:
      // Unknown mode!
      break;
  }
}

#pragma mark - Parent overrides

- (void)setHighlighted:(BOOL)highlighted
{
  static BOOL wasHighlighted = NO;
  [super setHighlighted:highlighted];

  if (self.isHighlighted && !wasHighlighted) {
    CABasicAnimation *highlightAnimation = [CABasicAnimation animationWithKeyPath:@"opacity"];
    highlightAnimation.toValue = @(0.2);
    highlightAnimation.duration = 0.10; // Step 1
    highlightAnimation.fillMode = kCAFillModeForwards;
    highlightAnimation.removedOnCompletion = NO;
    [self.centerElementLayer addAnimation:highlightAnimation forKey:@"make almost transparent"];
  }
  else if (!self.isHighlighted && wasHighlighted) {
    CABasicAnimation *unHighlightAnimation = [CABasicAnimation animationWithKeyPath:@"opacity"];
    unHighlightAnimation.toValue = @(1.0);
    unHighlightAnimation.duration = 0.25; // Step 1
    unHighlightAnimation.fillMode = kCAFillModeForwards;
    unHighlightAnimation.removedOnCompletion = NO;
    [self.centerElementLayer addAnimation:unHighlightAnimation forKey:@"make opaque"];
  }

  wasHighlighted = self.isHighlighted;
}

- (void)setEnabled:(BOOL)enabled
{
  [super setEnabled:enabled];
  [self setNeedsDisplay];
}

#pragma mark - Helpers

- (UIBezierPath *)tweenableBezierPathWithRoundedRect:(CGRect)roundedRectFrame cornerRadius:(CGFloat)cornerRadius
{
  // Only works for squares!
  // Kind of a mess, [UIBezierPath bezierPathWithRoundedRect:cornerRadius:] doesn't path-tween cleanly
  const CGFloat rectWidth = CGRectGetWidth(roundedRectFrame);

  // This is Apple's variation on "Kappa?"
  // http://nacho4d-nacho4d.blogspot.com/2011/05/bezier-paths-rounded-corners-rectangles.html
  const CGFloat curveMultiplier = 0.4476666667;
  const CGFloat curveHandleOffset = cornerRadius * curveMultiplier;

  //// roundedRect Drawing
  UIBezierPath *roundedRectPath = [UIBezierPath bezierPath];
  [roundedRectPath moveToPoint:CGPointMake(CGRectGetMinX(roundedRectFrame), CGRectGetMinY(roundedRectFrame) + (rectWidth - cornerRadius))];
  [roundedRectPath addCurveToPoint:CGPointMake(CGRectGetMinX(roundedRectFrame) + cornerRadius, CGRectGetMinY(roundedRectFrame) + rectWidth)
                     controlPoint1:CGPointMake(CGRectGetMinX(roundedRectFrame), CGRectGetMinY(roundedRectFrame) + (rectWidth - curveHandleOffset))
                     controlPoint2:CGPointMake(CGRectGetMinX(roundedRectFrame) + curveHandleOffset, CGRectGetMinY(roundedRectFrame) + rectWidth)];
  [roundedRectPath addLineToPoint:CGPointMake(CGRectGetMinX(roundedRectFrame) + (rectWidth - cornerRadius), CGRectGetMinY(roundedRectFrame) + rectWidth)];
  [roundedRectPath addCurveToPoint:CGPointMake(CGRectGetMinX(roundedRectFrame) + rectWidth, CGRectGetMinY(roundedRectFrame) + (rectWidth - cornerRadius))
                     controlPoint1:CGPointMake(CGRectGetMinX(roundedRectFrame) + (rectWidth - curveHandleOffset), CGRectGetMinY(roundedRectFrame) + rectWidth)
                     controlPoint2:CGPointMake(CGRectGetMinX(roundedRectFrame) + rectWidth, CGRectGetMinY(roundedRectFrame) + (rectWidth - curveHandleOffset))];
  [roundedRectPath addLineToPoint:CGPointMake(CGRectGetMinX(roundedRectFrame) + rectWidth, CGRectGetMinY(roundedRectFrame) + cornerRadius)];
  [roundedRectPath addCurveToPoint:CGPointMake(CGRectGetMinX(roundedRectFrame) + (rectWidth - cornerRadius), CGRectGetMinY(roundedRectFrame))
                     controlPoint1:CGPointMake(CGRectGetMinX(roundedRectFrame) + rectWidth, CGRectGetMinY(roundedRectFrame) + curveHandleOffset)
                     controlPoint2:CGPointMake(CGRectGetMinX(roundedRectFrame) + (rectWidth - curveHandleOffset), CGRectGetMinY(roundedRectFrame))];
  [roundedRectPath addLineToPoint:CGPointMake(CGRectGetMinX(roundedRectFrame) + cornerRadius, CGRectGetMinY(roundedRectFrame))];
  [roundedRectPath addCurveToPoint:CGPointMake(CGRectGetMinX(roundedRectFrame), CGRectGetMinY(roundedRectFrame) + cornerRadius)
                     controlPoint1:CGPointMake(CGRectGetMinX(roundedRectFrame) + curveHandleOffset, CGRectGetMinY(roundedRectFrame))
                     controlPoint2:CGPointMake(CGRectGetMinX(roundedRectFrame), CGRectGetMinY(roundedRectFrame) + curveHandleOffset)];
  [roundedRectPath addLineToPoint:CGPointMake(CGRectGetMinX(roundedRectFrame), CGRectGetMinY(roundedRectFrame) + (rectWidth - cornerRadius))];
  [roundedRectPath closePath];

  return roundedRectPath;
}

#pragma mark - Parent overrides

// Only override drawRect: if you perform custom drawing.
// An empty implementation adversely affects performance during animation.
//- (void)drawRect:(CGRect)rect {
//    NSLog(@"draw");
//    [[UIColor redColor] setStroke];
//    [self.path stroke];
//
//
//    //UIBezierPath* circlePath = [UIBezierPath bezierPathWithOvalInRect: CGRectMake(16, 14, 90, 90)];
//
//
//
//
//
//}

@end
