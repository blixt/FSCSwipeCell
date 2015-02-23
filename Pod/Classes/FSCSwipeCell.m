#import "FSCSwipeCell.h"

NSTimeInterval const kFSCSwipeCellAnimationDuration = 0.1;
CGFloat const kFSCSwipeCellBounceElasticity = 0.2;
CGFloat const kFSCSwipeCellOpenDistanceThreshold = 75;
CGFloat const kFSCSwipeCellOpenVelocityThreshold = 500;

FSCSwipeCell *FSCSwipeCellCurrentSwipingCell;

#pragma mark - FSCSwipeCell

@interface FSCSwipeCell ()

@property (nonatomic, strong) CADisplayLink *displayLink;
@property (nonatomic) CFAbsoluteTime lastPanEventTime;
@property (nonatomic, strong) UIPanGestureRecognizer *panGestureRecognizer;
@property (nonatomic) BOOL swiping;
@property (nonatomic, strong) UIView *wrapper;

@end

@implementation FSCSwipeCell

#pragma mark Lifecycle methods

- (void)awakeFromNib {
    [super awakeFromNib];
    [self setUp];
}

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        [self setUp];
    }
    return self;
}

- (void)setUp {
    _panGestureRecognizer = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(cellWasSwiped:)];
    _panGestureRecognizer.delaysTouchesBegan = YES;
    _panGestureRecognizer.delegate = self;
    [self addGestureRecognizer:_panGestureRecognizer];

    // Create a wrapper view which will change its bounds to move the content view left/right.
    _wrapper = [[UIView alloc] initWithFrame:self.bounds];
    _wrapper.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _wrapper.userInteractionEnabled = NO;
    [self addSubview:_wrapper];

    // Move the content view into the wrapper.
    UIView *contentView = self.contentView;
    [contentView removeFromSuperview];
    [_wrapper addSubview:contentView];

    // Remove the white background color from the cell itself.
    self.backgroundColor = [UIColor clearColor];

    // Make the content view white since it can now uncover things behind it.
    contentView.backgroundColor = [UIColor whiteColor];
}

#pragma mark Properties

- (void)setCurrentSide:(FSCSwipeCellSide)side {
    [self setCurrentSide:side duration:kFSCSwipeCellAnimationDuration];
}

- (void)setCurrentSide:(FSCSwipeCellSide)side duration:(NSTimeInterval)duration {
    if (duration > 0 && side == _currentSide) return;
    [self setOffset:(self.bounds.size.width * side) duration:duration];
}

- (void)setLeftView:(UIView *)view {
    if (view == _leftView) return;
    if (_leftView) [_leftView removeFromSuperview];
    _leftView = view;

    if (view) {
        view.hidden = (self.offset >= 0);
        view.frame = CGRectMake(0, 0, self.bounds.size.width, self.bounds.size.height);
        [self insertSubview:view belowSubview:self.wrapper];
    }
}

- (void)setOffset:(CGFloat)x {
    [self setOffset:x duration:kFSCSwipeCellAnimationDuration completion:nil];
}

- (void)setOffset:(CGFloat)x duration:(NSTimeInterval)duration {
    [self setOffset:x duration:duration completion:nil];
}

- (void)setOffset:(CGFloat)x completion:(void (^)(BOOL finished))completion {
    [self setOffset:x duration:kFSCSwipeCellAnimationDuration completion:completion];
}

- (void)setOffset:(CGFloat)x duration:(NSTimeInterval)duration completion:(void (^)(BOOL finished))completion {
    // Determine which side is showing, and what side will show.
    FSCSwipeCellSide previousSide = (_offset < 0 ? FSCSwipeCellSideLeft : (_offset > 0 ? FSCSwipeCellSideRight : FSCSwipeCellSideNone));
    FSCSwipeCellSide side = (x < 0 ? FSCSwipeCellSideLeft : (x > 0 ? FSCSwipeCellSideRight : FSCSwipeCellSideNone));

    // Handle sides changing.
    if (side != previousSide && side != FSCSwipeCellSideNone && [self.delegate respondsToSelector:@selector(swipeCell:shouldShowSide:)]) {
        // Ask the delegate if the side should show.
        if (![self.delegate swipeCell:self shouldShowSide:side]) {
            // Instantly reset the offset to 0.
            x = 0;
            side = FSCSwipeCellSideNone;
            duration = 0;
        }
    }

    // Update the underlying variable holding the offset.
    _offset = x;

    // Update the current side if it's fully exposed and the cell is not being swiped.
    if (!self.swiping && side != self.currentSide && x == side * self.bounds.size.width) {
        _currentSide = side;
        // Let the delegate know of side changes.
        if ([self.delegate respondsToSelector:@selector(swipeCellDidChangeCurrentSide:)]) {
            [self.delegate swipeCellDidChangeCurrentSide:self];
        }
    }

    // Apply bounce.
    if ((x < 0 && !self.leftView) || (x > 0 && !self.rightView)) {
        x *= kFSCSwipeCellBounceElasticity;
    }

    // Convenience block for calling delegates and callbacks.
    void (^done)(BOOL) = ^(BOOL finished){
        if (finished && side != previousSide && previousSide != FSCSwipeCellSideNone) {
            if ([self.delegate respondsToSelector:@selector(swipeCell:didHideSide:)]) {
                [self.delegate swipeCell:self didHideSide:previousSide];
            }
        }
        if (completion) completion(finished);
    };

    // Calculate the destination bounds.
    CGRect bounds = CGRectMake(x, 0, self.bounds.size.width, self.bounds.size.height);

    dispatch_async(dispatch_get_main_queue(), ^{
        // Perform the change instantly if no duration was specified.
        if (duration <= 0) {
            [self.wrapper.layer removeAllAnimations];
            self.wrapper.bounds = bounds;
            [self reportOffset:x];
            done(YES);
            return;
        }

        // Create a timer which will update the delegate every frame.
        if (self.displayLink) {
            [self.displayLink invalidate];
        }
        self.displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(frameTick:)];
        [self.displayLink addToRunLoop:[NSRunLoop currentRunLoop] forMode:NSRunLoopCommonModes];

        // Animate the movement of the cell.
        [UIView animateWithDuration:duration
                         animations:^{
                             self.wrapper.bounds = bounds;
                         }
                         completion:^(BOOL finished) {
                             [self.displayLink invalidate];
                             self.displayLink = nil;
                             done(finished);
                         }];
    });
}

- (void)setRightView:(UIView *)view {
    if (view == _rightView) return;
    if (_rightView) [_rightView removeFromSuperview];
    _rightView = view;

    if (view) {
        view.hidden = (self.offset <= 0);
        view.frame = CGRectMake(0, 0, self.bounds.size.width, self.bounds.size.height);
        [self insertSubview:view belowSubview:self.wrapper];
    }
}

#pragma mark Private methods

- (void)cellWasSwiped:(UIPanGestureRecognizer *)sender {
    CGFloat velocity = -[sender velocityInView:self].x;
    CGFloat width = self.bounds.size.width;

    // Get the swiped distance.
    CGFloat x = self.offset - [sender translationInView:self].x;
    // Constrain the offset to be within bounds.
    x = MAX(MIN(x, self.bounds.size.width), -self.bounds.size.width);
    // Reset the pan gesture's translation offset.
    [sender setTranslation:CGPointZero inView:self];

    // Handle the various dragging states.
    switch (sender.state) {
        case UIGestureRecognizerStateBegan:
            // Atomically set the currently swiping cell (or if one is already swiping, ignore this one).
            @synchronized([FSCSwipeCell class]) {
                if (FSCSwipeCellCurrentSwipingCell) {
                    // Another cell is already being swiped, cancel this gesture.
                    sender.enabled = NO;
                    return;
                }
                FSCSwipeCellCurrentSwipingCell = self;
            }

            self.swiping = YES;

            // Notify the delegate that swiping has commenced.
            if ([self.delegate respondsToSelector:@selector(swipeCellWillBeginSwiping:)]) {
                [self.delegate swipeCellWillBeginSwiping:self];
            }

            // Intentional fall-through of control.
        case UIGestureRecognizerStateChanged:
            // Move the cell content instantly.
            [self setOffset:x duration:0];
            break;
        case UIGestureRecognizerStateEnded:
        {
            // Reduce the velocity based on how long has passed since the user dragged.
            velocity /= CFAbsoluteTimeGetCurrent() - self.lastPanEventTime + 1;

            // Atomically unset the currently swiping cell (or bail if this cell isn't the main swiping cell).
            @synchronized([FSCSwipeCell class]) {
                FSCSwipeCellCurrentSwipingCell = nil;
            }

            self.swiping = NO;

            BOOL goingLeft = (velocity > kFSCSwipeCellOpenVelocityThreshold);
            BOOL goingRight = (velocity < -kFSCSwipeCellOpenVelocityThreshold);

            BOOL resetOffset = NO;
            switch (self.currentSide) {
                case FSCSwipeCellSideLeft:
                    // Return to default state unless the user swiped in the open direction.
                    if (!goingRight && x > -width) {
                        self.currentSide = FSCSwipeCellSideNone;
                    } else {
                        resetOffset = YES;
                    }
                    break;
                case FSCSwipeCellSideNone:
                    // Open the relevant side (if it has a style and the user swiped beyond the threshold).
                    if (self.leftView && ((x <= 0 && goingRight) || (x < -kFSCSwipeCellOpenDistanceThreshold && !goingLeft))) {
                        self.currentSide = FSCSwipeCellSideLeft;
                    } else if (self.rightView && ((x >= 0 && goingLeft) || (x > kFSCSwipeCellOpenDistanceThreshold && !goingRight))) {
                        self.currentSide = FSCSwipeCellSideRight;
                    } else {
                        resetOffset = YES;
                    }
                    break;
                case FSCSwipeCellSideRight:
                    // Return to default state unless the user swiped in the open direction.
                    if (!goingLeft && x < width) {
                        self.currentSide = FSCSwipeCellSideNone;
                    } else {
                        resetOffset = YES;
                    }
                    break;
            }

            if (resetOffset) {
                self.offset = self.currentSide * width;
            }

            // Notify the delegate that swiping has ended.
            if ([self.delegate respondsToSelector:@selector(swipeCellDidEndSwiping:)]) {
                [self.delegate swipeCellDidEndSwiping:self];
            }

            break;
        }
        case UIGestureRecognizerStateCancelled:
            // Restore the gesture recognizer once it's been cancelled.
            sender.enabled = YES;
            break;
        default:
            return;
    }
    self.lastPanEventTime = CFAbsoluteTimeGetCurrent();
}

- (void)frameTick:(CADisplayLink *)sender {
    CALayer *layer = self.wrapper.layer.presentationLayer;
    [self reportOffset:layer.bounds.origin.x];
}

- (void)reportOffset:(CGFloat)x {
    FSCSwipeCellSide side = (x < 0 ? FSCSwipeCellSideLeft : (x > 0 ? FSCSwipeCellSideRight : FSCSwipeCellSideNone));
    if (self.leftView) self.leftView.hidden = side != FSCSwipeCellSideLeft;
    if (self.rightView) self.rightView.hidden = side != FSCSwipeCellSideRight;
    if (x != 0 && [self.delegate respondsToSelector:@selector(swipeCell:didSwipe:side:)]) {
        [self.delegate swipeCell:self didSwipe:fabs(x) side:side];
    }
}

#pragma mark UIGestureRecognizerDelegate

- (BOOL)gestureRecognizerShouldBegin:(UIPanGestureRecognizer *)recognizer {
    if (recognizer != self.panGestureRecognizer) {
        if ([[FSCSwipeCell superclass] instancesRespondToSelector:@selector(gestureRecognizerShouldBegin:)]) {
            return [super gestureRecognizerShouldBegin:recognizer];
        } else {
            return YES;
        }
    }

    CGPoint translation = [recognizer translationInView:self];
    // Fail vertical swipes.
    return (fabs(translation.y) <= fabs(translation.x));
}

- (BOOL)gestureRecognizer:(UIPanGestureRecognizer *)recognizer shouldBeRequiredToFailByGestureRecognizer:(UIGestureRecognizer *)other {
    if (recognizer != self.panGestureRecognizer) {
        if ([[FSCSwipeCell superclass] instancesRespondToSelector:@selector(gestureRecognizer:shouldBeRequiredToFailByGestureRecognizer:)]) {
            return [super gestureRecognizer:recognizer shouldBeRequiredToFailByGestureRecognizer:other];
        } else {
            return NO;
        }
    }

    return [other isKindOfClass:[UIPanGestureRecognizer class]];
}

#pragma mark UITableViewCell

- (void)prepareForReuse {
    [self setOffset:0 duration:0];
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated {
    [super setSelected:selected animated:animated];
    if (selected) {
        // Move the selected background view into the wrapper.
        [self.wrapper insertSubview:self.selectedBackgroundView atIndex:0];
    }
}

#pragma mark UIView

- (void)layoutSubviews {
    [super layoutSubviews];

    // Update the left/right view layouts.
    CGRect frame = CGRectMake(0, 0, self.bounds.size.width, self.bounds.size.height);
    if (self.leftView) self.leftView.frame = frame;
    if (self.rightView) self.rightView.frame = frame;

}

- (void)willRemoveSubview:(UIView *)subview {
    if (_leftView == subview) _leftView = nil;
    if (_rightView == subview) _rightView = nil;
}

@end
