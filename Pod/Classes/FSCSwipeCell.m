#import "FSCSwipeCell.h"

NSTimeInterval const kFSCSwipeCellAnimationDuration = 0.1;
CGFloat const kFSCSwipeCellBounceElasticity = 0.2;
CGFloat const kFSCSwipeCellOpenDistanceThreshold = 75;
CGFloat const kFSCSwipeCellOpenVelocityThreshold = 500;

FSCSwipeCell *FSCSwipeCellCurrentSwipingCell;

#pragma mark - FSCSwipeCell

@interface FSCSwipeCell ()

@property (nonatomic) CFAbsoluteTime lastPanEventTime;
@property (nonatomic) FSCSwipeCellSide lastShownSide;
@property (nonatomic, strong) UIPanGestureRecognizer *panGestureRecognizer;
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
    [self addSubview:_wrapper];

    // Move the content view into the wrapper.
    UIView *contentView = self.contentView;
    [contentView removeFromSuperview];
    [_wrapper addSubview:contentView];

    // Make the content view white since it can now uncover things behind it.
    contentView.backgroundColor = [UIColor whiteColor];
}

#pragma mark Properties

- (void)setCurrentSide:(FSCSwipeCellSide)side {
    [self setCurrentSide:side duration:kFSCSwipeCellAnimationDuration];
}

- (void)setCurrentSide:(FSCSwipeCellSide)side duration:(NSTimeInterval)duration {
    if (side == _currentSide) {
        // No change needed. However, if an animation is in flight and this call has animated = NO, the animation
        // will continue. We don't cancel the animation here because it could break the didHideSide delegate call.
        return;
    }

    FSCSwipeCellSide previousSide = _currentSide;
    _currentSide = side;

    // Let the delegate know that the side changed.
    if ([self.delegate respondsToSelector:@selector(swipeCellDidChangeCurrentSide:)]) {
        [self.delegate swipeCellDidChangeCurrentSide:self];
    }

    // Update the view and notify the delegate if relevant.
    __weak FSCSwipeCell *cell = self;
    [self setOffset:(self.bounds.size.width * side) duration:duration completion:^(BOOL finished) {
        if (finished && side == FSCSwipeCellSideNone && [cell.delegate respondsToSelector:@selector(swipeCell:didHideSide:)]) {
            [cell.delegate swipeCell:cell didHideSide:previousSide];
        }
    }];
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

- (void)setOffset:(CGFloat)x completion:(void (^)(BOOL finished))completion {
    [self setOffset:x duration:kFSCSwipeCellAnimationDuration completion:completion];
}

- (void)setOffset:(CGFloat)x duration:(NSTimeInterval)duration {
    [self setOffset:x duration:duration completion:nil];
}

- (void)setOffset:(CGFloat)x duration:(NSTimeInterval)duration completion:(void (^)(BOOL finished))completion {
    _offset = x;

    // Calculate the destination bounds.
    CGRect bounds = CGRectMake(x, 0, self.bounds.size.width, self.bounds.size.height);

    dispatch_async(dispatch_get_main_queue(), ^{
        if (duration <= 0) {
            self.wrapper.bounds = bounds;
            if (completion) {
                completion(YES);
            }
            return;
        }

        [UIView animateWithDuration:duration
                         animations:^{
                             self.wrapper.bounds = bounds;
                         }
                         completion:^(BOOL finished) {
                             if (self.leftView && self.currentSide != FSCSwipeCellSideLeft) {
                                 self.leftView.hidden = YES;
                             }

                             if (self.rightView && self.currentSide != FSCSwipeCellSideRight) {
                                 self.rightView.hidden = YES;
                             }

                             if (completion) {
                                 completion(finished);
                             }
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
                self.lastShownSide = self.currentSide;
            }

            // Position the left/right views under the content view.
            CGRect frame = CGRectMake(0, 0, self.bounds.size.width, self.bounds.size.height);
            if (self.leftView) self.leftView.frame = frame;
            if (self.rightView) self.rightView.frame = frame;

            // Intentional fall-through of control.
        case UIGestureRecognizerStateChanged:
        {
            // Determine which side is showing.
            FSCSwipeCellSide side = (x < 0 ? FSCSwipeCellSideLeft : (x > 0 ? FSCSwipeCellSideRight : FSCSwipeCellSideNone));
            // Handle sides changing.
            if (side != self.lastShownSide) {
                if (side != FSCSwipeCellSideNone && [self.delegate respondsToSelector:@selector(swipeCell:shouldShowSide:)]) {
                    // Ask the delegate if the side should show.
                    if (![self.delegate swipeCell:self shouldShowSide:side]) {
                        // Don't allow swiping of the cell (but keep the gesture active).
                        [self setOffset:0 duration:0];
                        return;
                    }
                }
                self.lastShownSide = side;
            }

            // Update the visibility of the left/right swipe views.
            if (self.leftView) self.leftView.hidden = (x >= 0);
            if (self.rightView) self.rightView.hidden = (x <= 0);

            // Move the cell content instantly.
            [self setOffset:x duration:0];

            // Let the delegate know that the cell was swiped.
            if ([self.delegate respondsToSelector:@selector(swipeCell:didSwipe:side:)]) {
                if ((side == FSCSwipeCellSideLeft && self.leftView) || (side == FSCSwipeCellSideRight && self.rightView)) {
                    [self.delegate swipeCell:self didSwipe:abs(x) side:side];
                }
            }

            break;
        }
        case UIGestureRecognizerStateEnded:
        {
            // Reduce the velocity based on how long has passed since the user dragged.
            velocity /= CFAbsoluteTimeGetCurrent() - self.lastPanEventTime + 1;

            // Atomically unset the currently swiping cell (or bail if this cell isn't the main swiping cell).
            @synchronized([FSCSwipeCell class]) {
                FSCSwipeCellCurrentSwipingCell = nil;
            }

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
                // Update the view and notify the delegate if relevant.
                FSCSwipeCellSide side = self.currentSide;
                __weak FSCSwipeCell *cell = self;
                [self setOffset:(side * width) completion:^(BOOL finished) {
                    if (finished && cell.currentSide == FSCSwipeCellSideNone && x != 0) {
                        if ([cell.delegate respondsToSelector:@selector(swipeCell:didHideSide:)]) {
                            [cell.delegate swipeCell:cell didHideSide:(x < 0 ? FSCSwipeCellSideLeft : FSCSwipeCellSideRight)];
                        }
                    }
                }];
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

#pragma mark UIGestureRecognizerDelegate

- (BOOL)gestureRecognizerShouldBegin:(UIPanGestureRecognizer *)recognizer {
    if (recognizer != self.panGestureRecognizer) {
        if ([[self superclass] instancesRespondToSelector:@selector(gestureRecognizerShouldBegin:)]) {
            return [super gestureRecognizerShouldBegin:recognizer];
        } else {
            return YES;
        }
    }

    CGPoint translation = [recognizer translationInView:self];
    // Fail vertical swipes.
    return (abs(translation.y) < abs(translation.x));
}

- (BOOL)gestureRecognizer:(UIPanGestureRecognizer *)recognizer shouldBeRequiredToFailByGestureRecognizer:(UIGestureRecognizer *)other {
    if (recognizer != self.panGestureRecognizer) {
        if ([[self superclass] instancesRespondToSelector:@selector(gestureRecognizer:shouldBeRequiredToFailByGestureRecognizer:)]) {
            return [super gestureRecognizer:recognizer shouldBeRequiredToFailByGestureRecognizer:other];
        } else {
            return NO;
        }
    }

    return YES;
}

#pragma mark UITableViewCell

- (void)prepareForReuse {
    [self setCurrentSide:FSCSwipeCellSideNone duration:0];
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated {
    [super setSelected:selected animated:animated];
    if (selected) {
        // Move the selected background view into the wrapper.
        [self.wrapper insertSubview:self.selectedBackgroundView atIndex:0];
    }
}

#pragma mark UIView

- (void)willRemoveSubview:(UIView *)subview {
    if (_leftView == subview) _leftView = nil;
    if (_rightView == subview) _rightView = nil;
}

@end
