//
//  JCTiledScrollView.m
//
//  Created by Jesse Collis on 1/2/2012.
//  Copyright (c) 2012, Jesse Collis JC Multimedia Design.
//  <jesse@jcmultimedia.com.au>
//  All rights reserved.
//
//  * Redistribution and use in source and binary forms, with or without
//   modification, are permitted provided that the following conditions are met:
//
//  * Redistributions of source code must retain the above copyright
//   notice, this list of conditions and the following disclaimer.
//
//  * Redistributions in binary form must reproduce the above copyright
//   notice, this list of conditions and the following disclaimer in the
//   documentation and/or other materials provided with the distribution.
//
//  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
//  AND
//  ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
//  IMPLIED
//  WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
//  DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
//  FOR ANY
//  DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
//  (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
//  LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
//  ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
//  (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
//  THIS
//  SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE
//

#import "JCTiledScrollView.h"

#import "JCTiledScrollView-Swift.h"

#import "ADAnnotationTapGestureRecognizer.h"

#define kStandardUIScrollViewAnimationTime (int64_t)0.10

@interface JCTiledScrollView () <JCTiledBitmapViewDelegate,
                                 UIGestureRecognizerDelegate>

@property (nonatomic, strong) UITapGestureRecognizer* singleTapGestureRecognizer;
@property (nonatomic, strong) UITapGestureRecognizer* doubleTapGestureRecognizer;
@property (nonatomic, strong)
    UITapGestureRecognizer* twoFingerTapGestureRecognizer;
@end

@implementation JCTiledScrollView

+ (Class)tiledLayerClass
{
    return [JCTiledView class];
}

- (id)initWithFrame:(CGRect)frame contentSize:(CGSize)contentSize
{
    if ((self = [super initWithFrame:frame])) {
        self.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;

        _scrollView = [[UIScrollView alloc] initWithFrame:self.bounds];
        _scrollView.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;
        _scrollView.delegate = self;
        _scrollView.backgroundColor = [UIColor whiteColor];
        _scrollView.contentSize = contentSize;
        _scrollView.bouncesZoom = YES;
        _scrollView.bounces = YES;
        _scrollView.minimumZoomScale = 1.0;

        self.levelsOfZoom = 2;

        self.zoomsInOnDoubleTap = YES;
        self.zoomsOutOnTwoFingerTap = YES;
        self.centerSingleTap = YES;

        CGRect canvas_frame = CGRectMake(0.0f, 0.0f, _scrollView.contentSize.width,
                                         _scrollView.contentSize.height);
        _canvasView = [[UIView alloc] initWithFrame:canvas_frame];
        _canvasView.userInteractionEnabled = NO;

        _tiledView =
            [[[[self class] tiledLayerClass] alloc] initWithFrame:canvas_frame];
        _tiledView.delegate = self;

        [_scrollView addSubview:self.tiledView];

        [self addSubview:_scrollView];
        [self addSubview:_canvasView];

        _singleTapGestureRecognizer = [[ADAnnotationTapGestureRecognizer alloc]
            initWithTarget:self
                    action:@selector(singleTapReceived:)];
        _singleTapGestureRecognizer.numberOfTapsRequired = 1;
        _singleTapGestureRecognizer.delegate = self;
        [_tiledView addGestureRecognizer:_singleTapGestureRecognizer];

        _doubleTapGestureRecognizer = [[UITapGestureRecognizer alloc]
            initWithTarget:self
                    action:@selector(doubleTapReceived:)];
        _doubleTapGestureRecognizer.numberOfTapsRequired = 2;
        [_tiledView addGestureRecognizer:_doubleTapGestureRecognizer];

        [_singleTapGestureRecognizer
            requireGestureRecognizerToFail:_doubleTapGestureRecognizer];

        _twoFingerTapGestureRecognizer = [[UITapGestureRecognizer alloc]
            initWithTarget:self
                    action:@selector(twoFingerTapReceived:)];
        _twoFingerTapGestureRecognizer.numberOfTouchesRequired = 2;
        _twoFingerTapGestureRecognizer.numberOfTapsRequired = 1;
        [_tiledView addGestureRecognizer:_twoFingerTapGestureRecognizer];

        _annotations = [[NSMutableSet alloc] init];
        _visibleAnnotations = [[NSMutableSet alloc] init];
        _recycledAnnotationViews = [[NSMutableSet alloc] init];
        _previousSelectedAnnotationTuple = nil;
        _currentSelectedAnnotationTuple = nil;

        _muteAnnotationUpdates = NO;
    }
    return self;
}

#pragma mark - UIScrolViewDelegate

- (UIView*)viewForZoomingInScrollView:(__unused UIScrollView*)scrollView
{
	return [self t_viewForZoomingInScrollView:scrollView];
}

- (void)scrollViewDidZoom:(__unused UIScrollView*)scrollView
{
	[self t_scrollViewDidZoom:scrollView];
}

- (void)scrollViewDidScroll:(__unused UIScrollView*)scrollView
{
	[self t_scrollViewDidScroll:scrollView];
}

#pragma mark -

// FIXME: Jesse C - I don't like overloading this here, but the logic is in one
// place
- (void)setMuteAnnotationUpdates:(BOOL)muteAnnotationUpdates
{
    _muteAnnotationUpdates = muteAnnotationUpdates;
    _scrollView.userInteractionEnabled = !_muteAnnotationUpdates;

    if (!muteAnnotationUpdates) {
        [self correctScreenPositionOfAnnotations];
    }
}

#pragma mark - Gesture Support

- (void)singleTapReceived:(UITapGestureRecognizer*)gestureRecognizer
{
	[self t_singleTapReceived:gestureRecognizer];
}

- (void)doubleTapReceived:(UITapGestureRecognizer*)gestureRecognizer
{
	[self t_doubleTapReceived:gestureRecognizer];
}

- (void)twoFingerTapReceived:(UITapGestureRecognizer*)gestureRecognizer
{
	[self t_twoFingerTapReceived:gestureRecognizer];
}

- (CGPoint)screenPositionForAnnotation:(id<JCAnnotation>)annotation
{
	return [self t_screenPositionForAnnotation:annotation];
}

- (void)correctScreenPositionOfAnnotations
{
    [CATransaction begin];
    [CATransaction setAnimationDuration:0.0];

    if ((_scrollView.isZoomBouncing || _muteAnnotationUpdates) && !_scrollView.isZooming) {
        for (JCVisibleAnnotationTuple* t in _visibleAnnotations) {
            t.view.position = [self screenPositionForAnnotation:t.annotation];
        }
    }
    else {
        for (id<JCAnnotation> annotation in _annotations) {

            CGPoint screenPosition = [self screenPositionForAnnotation:annotation];
            JCVisibleAnnotationTuple* t =
                [_visibleAnnotations visibleAnnotationTupleForAnnotation:annotation];

            if ([self point:screenPosition isWithinBounds:self.bounds]) {
                if (nil == t) {
                    JCAnnotationView* view =
                        [_tiledScrollViewDelegate tiledScrollView:self
                                                viewForAnnotation:annotation];

                    if (nil == view)
                        continue;
                    view.position = screenPosition;

                    t = [JCVisibleAnnotationTuple instanceWithAnnotation:annotation
                                                                    view:view];
                    if ([self.tiledScrollViewDelegate
                            respondsToSelector:@selector(tiledScrollView:
                                                    annotationWillAppear:)]) {
                        [self.tiledScrollViewDelegate tiledScrollView:self
                                                 annotationWillAppear:t.annotation];
                    }

                    if (t) {
                        [_visibleAnnotations addObject:t];
                        [_canvasView addSubview:t.view];
                    }

                    [CATransaction setValue:(id)kCFBooleanTrue
                                     forKey:kCATransactionDisableActions];
                    CABasicAnimation* theAnimation =
                        [CABasicAnimation animationWithKeyPath:@"opacity"];
                    theAnimation.duration = 0.3;
                    theAnimation.repeatCount = 1;
                    theAnimation.fromValue = [NSNumber numberWithFloat:0.0];
                    theAnimation.toValue = [NSNumber numberWithFloat:1.0];
                    [t.view.layer addAnimation:theAnimation forKey:@"animateOpacity"];

                    if ([self.tiledScrollViewDelegate
                            respondsToSelector:@selector(tiledScrollView:
                                                     annotationDidAppear:)]) {
                        [self.tiledScrollViewDelegate tiledScrollView:self
                                                  annotationDidAppear:t.annotation];
                    }
                }
                else {
                    if (t == _currentSelectedAnnotationTuple) {
                        [_canvasView addSubview:t.view];
                    }
                    t.view.position = screenPosition;
                }
            }
            else {
                if (nil != t) {
                    if ([self.tiledScrollViewDelegate
                            respondsToSelector:@selector(tiledScrollView:
                                                   annotationWillDisappear:)]) {
                        [self.tiledScrollViewDelegate tiledScrollView:self
                                                 annotationWillAppear:t.annotation];
                    }

                    if (t != _currentSelectedAnnotationTuple) {
                        [t.view removeFromSuperview];
                        if (t.view) {
                            [_recycledAnnotationViews addObject:t.view];
                        }
                        [_visibleAnnotations removeObject:t];
                    }
                    else {
                        // FIXME: Anthony D - I don't like let the view in visible
                        // annotations array, but the logic is in one place
                        [t.view removeFromSuperview];
                    }

                    if ([self.tiledScrollViewDelegate
                            respondsToSelector:@selector(tiledScrollView:
                                                   annotationDidDisappear:)]) {
                        [self.tiledScrollViewDelegate tiledScrollView:self
                                               annotationDidDisappear:t.annotation];
                    }
                }
            }
        }
    }
    [CATransaction commit];
}

#pragma mark - UIGestureRecognizerDelegate
// Catch our own tap gesture if it is on an annotation view to set annotation
// Return NO to only recognize single tap on annotation
- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer*)gestureRecognizer
{
	return [self t_gestureRecognizerShouldBegin:gestureRecognizer];
}

#pragma mark - JCTiledScrollView

- (CGFloat)zoomScale
{
    return _scrollView.zoomScale;
}

- (void)setZoomScale:(CGFloat)zoomScale
{
    [self setZoomScale:zoomScale animated:NO];
}

- (void)setZoomScale:(CGFloat)zoomScale animated:(BOOL)animated
{
    [_scrollView setZoomScale:zoomScale animated:animated];
}

- (void)setLevelsOfZoom:(size_t)levelsOfZoom
{
    _levelsOfZoom = levelsOfZoom;
    _scrollView.maximumZoomScale = (float)powf(2.0f, MAX(0.0f, levelsOfZoom));
}

- (void)setLevelsOfDetail:(size_t)levelsOfDetail
{
    if (levelsOfDetail == 1)
        NSLog(@"Note: Setting levelsOfDetail to 1 causes strange behaviour");

    _levelsOfDetail = levelsOfDetail;
    [self.tiledView setNumberOfZoomLevels:levelsOfDetail];
}

- (void)setContentCenter:(CGPoint)center animated:(BOOL)animated
{
    CGPoint new_contentOffset = _scrollView.contentOffset;

    if (_scrollView.contentSize.width > _scrollView.bounds.size.width) {
        new_contentOffset.x = MAX(0.0f, (center.x * _scrollView.zoomScale) - (_scrollView.bounds.size.width / 2.0f));
        new_contentOffset.x = MIN(new_contentOffset.x,
                                  (_scrollView.contentSize.width - _scrollView.bounds.size.width));
    }

    if (_scrollView.contentSize.height > _scrollView.bounds.size.height) {
        new_contentOffset.y = MAX(0.0f, (center.y * _scrollView.zoomScale) - (_scrollView.bounds.size.height / 2.0f));
        new_contentOffset.y = MIN(new_contentOffset.y,
                                  (_scrollView.contentSize.height - _scrollView.bounds.size.height));
    }
    [_scrollView setContentOffset:new_contentOffset animated:animated];
}

#pragma mark - JCTileSource

- (UIImage*)tiledView:(__unused JCTiledView*)tiledView
          imageForRow:(NSInteger)row
               column:(NSInteger)column
                scale:(NSInteger)scale
{
    return [self.dataSource tiledScrollView:self
                                imageForRow:row
                                     column:column
                                      scale:scale];
}

#pragma mark - Annotation Recycling

- (JCAnnotationView*)dequeueReusableAnnotationViewWithReuseIdentifier:
                         (NSString*)reuseIdentifier
{
    id view = nil;

    for (JCAnnotationView* obj in _recycledAnnotationViews) {
        if ([[obj reuseIdentifier] isEqualToString:reuseIdentifier]) {
            view = obj;
            break;
        }
    }

    if (nil != view) {
        [_recycledAnnotationViews removeObject:view];
        return view;
    }
    return nil;
}

#pragma mark - Annotations

- (BOOL)point:(CGPoint)point isWithinBounds:(CGRect)bounds
{
    return CGRectContainsPoint(CGRectInset(bounds, -25., -25.), point);
}

- (void)refreshAnnotations
{
    [self correctScreenPositionOfAnnotations];

    for (id<JCAnnotation> annotation in _annotations) {

        CGPoint screenPosition = [self screenPositionForAnnotation:annotation];
        JCVisibleAnnotationTuple* t =
            [_visibleAnnotations visibleAnnotationTupleForAnnotation:annotation];

        [t.view setNeedsLayout];
        [t.view setNeedsDisplay];
    }
}

- (void)addAnnotation:(id<JCAnnotation>)annotation
{
    [_annotations addObject:annotation];

    CGPoint screenPosition = [self screenPositionForAnnotation:annotation];

    if ([self point:screenPosition isWithinBounds:self.bounds]) {
        JCAnnotationView* view =
            [_tiledScrollViewDelegate tiledScrollView:self
                                    viewForAnnotation:annotation];
        view.position = screenPosition;

        JCVisibleAnnotationTuple* t =
            [JCVisibleAnnotationTuple instanceWithAnnotation:annotation view:view];
        [_visibleAnnotations addObject:t];

        [_canvasView addSubview:view];
    }
}

- (void)addAnnotations:(NSArray*)annotations
{
    for (id annotation in annotations) {
        [self addAnnotation:annotation];
    }
}

- (void)removeAnnotation:(id<JCAnnotation>)annotation
{
    if ([_annotations containsObject:annotation]) {
        JCVisibleAnnotationTuple* t =
            [_visibleAnnotations visibleAnnotationTupleForAnnotation:annotation];
        if (t) {
            [t.view removeFromSuperview];
            [_visibleAnnotations removeObject:t];
        }

        [_annotations removeObject:annotation];
    }
}

- (void)removeAnnotations:(NSArray*)annotations
{
    for (id annotation in annotations) {
        [self removeAnnotation:annotation];
    }
}

- (void)removeAllAnnotations
{
    [self removeAnnotations:[_annotations allObjects]];
}

@end
