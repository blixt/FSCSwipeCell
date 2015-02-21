#import "FSCSwipeCell.h"

CGFloat const kFSCSwipeCellAnimationDuration = 0.15;
CGFloat const kFSCSwipeCellBounceElasticity = 0.3;
CGFloat const kFSCSwipeCellOpenDistanceThreshold = 75;
CGFloat const kFSCSwipeCellOpenVelocityThreshold = 500;

FSCSwipeCell *FSCSwipeCellCurrentSwipingCell;

#pragma mark - FSCSwipeCell

@interface FSCSwipeCell ()

@property (nonatomic) CFAbsoluteTime lastPanEventTime;
@property (nonatomic) FSCSwipeCellSide lastShownSide;
@property (nonatomic, strong) UIPanGestureRecognizer *panGestureRecognizer;

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
    [self addGestureRecognizer:_panGestureRecognizer];

    // Remove the white background color from the cell itself.
    self.backgroundColor = [UIColor clearColor];

    // Make the content view white since it can now uncover things behind it.
    self.contentView.backgroundColor = [UIColor whiteColor];
}

#pragma mark Properties

- (void)setCurrentSide:(FSCSwipeCellSide)side {
    [self setCurrentSide:side animated:YES];
}

- (void)setCurrentSide:(FSCSwipeCellSide)side animated:(BOOL)animated {
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
    [self swipeToOffset:(self.bounds.size.width * side) animated:animated completion:^(BOOL finished) {
        if (finished && side == FSCSwipeCellSideNone) {
            if ([self.delegate respondsToSelector:@selector(swipeCell:didHideSide:)]) {
                [self.delegate swipeCell:self didHideSide:previousSide];
            }
        }
    }];
}

- (void)setLeftView:(UIView *)view {
    if (view == _leftView) return;
    if (_leftView) [_leftView removeFromSuperview];
    _leftView = view;

    if (view) {
        view.frame = CGRectMake(0, 0, self.bounds.size.width, self.bounds.size.height);
        [self insertSubview:view atIndex:0];
    }
}

- (void)setRightView:(UIView *)view {
    if (view == _rightView) return;
    if (_rightView) [_rightView removeFromSuperview];
    _rightView = view;

    if (view) {
        view.frame = CGRectMake(0, 0, self.bounds.size.width, self.bounds.size.height);
        [self insertSubview:view atIndex:0];
    }
}

#pragma mark Private methods

- (void)cellWasSwiped:(UIPanGestureRecognizer *)sender {
    CGFloat velocity = -[sender velocityInView:self].x;
    CGFloat width = self.bounds.size.width;
    BOOL swiping;

    // Calculate the origin based on the current visible side of the cell.
    CGFloat x;
    switch (self.currentSide) {
        case FSCSwipeCellSideLeft:
            x = -width;
            break;
        case FSCSwipeCellSideNone:
            x = 0;
            break;
        case FSCSwipeCellSideRight:
            x = width;
            break;
    }

    // Update the X coordinate with the swiped distance.
    x -= [sender translationInView:self].x;

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
            if (self.leftView) self.leftView.frame = self.frame;
            if (self.rightView) self.rightView.frame = self.frame;

            swiping = YES;
            break;
        case UIGestureRecognizerStateChanged:
            swiping = YES;
            break;
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
                    if ((x <= 0 && goingRight) || (x < -kFSCSwipeCellOpenDistanceThreshold && !goingLeft)) {
                        self.currentSide = self.leftView ? FSCSwipeCellSideLeft : FSCSwipeCellSideNone;
                    } else if ((x >= 0 && goingLeft) || (x > kFSCSwipeCellOpenDistanceThreshold && !goingRight)) {
                        self.currentSide = self.rightView ? FSCSwipeCellSideRight : FSCSwipeCellSideNone;
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
                [self swipeToOffset:(side * width) animated:YES completion:^(BOOL finished) {
                    if (finished && self.currentSide == FSCSwipeCellSideNone && x != 0) {
                        if ([self.delegate respondsToSelector:@selector(swipeCell:didHideSide:)]) {
                            [self.delegate swipeCell:self didHideSide:(x < 0 ? FSCSwipeCellSideLeft : FSCSwipeCellSideRight)];
                        }
                    }
                }];
            }

            swiping = NO;
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

    // Figure out which side will show.
    FSCSwipeCellSide side = (x < 0 ? FSCSwipeCellSideLeft : (x > 0 ? FSCSwipeCellSideRight : FSCSwipeCellSideNone));
    if (side != self.lastShownSide) {
        self.lastShownSide = side;
        if (side != FSCSwipeCellSideNone && [self.delegate respondsToSelector:@selector(swipeCell:shouldShowSide:)]) {
            // Ask the delegate if the side should show.
            if (![self.delegate swipeCell:self shouldShowSide:side]) {
                // Cancel the swipe.
                x = 0;
            }
        }
    }

    // Update the visibility of the left/right swipe views.
    if (x != 0 || swiping) {
        if (self.leftView) self.leftView.hidden = (x >= 0);
        if (self.rightView) self.rightView.hidden = (x <= 0);
    }

    // Move the cell content.
    self.bounds = CGRectOffset(self.frame, x, 0);

    // Let the delegate know that the cell was swiped.
    if ([self.delegate respondsToSelector:@selector(swipeCell:didSwipe:side:)]) {
        if ((side == FSCSwipeCellSideLeft && self.leftView) || (side == FSCSwipeCellSideRight && self.rightView)) {
            [self.delegate swipeCell:self didSwipe:abs(x) side:side];
        }
    }
}

- (void)swipeToOffset:(CGFloat)x animated:(BOOL)animated {
    [self swipeToOffset:x animated:animated completion:nil];
}

- (void)swipeToOffset:(CGFloat)x animated:(BOOL)animated completion:(void (^)(BOOL finished))completion {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (!animated) {
            self.bounds = CGRectOffset(self.frame, x, 0);
            if (completion) {
                completion(YES);
            }
            return;
        }

        // We use animateWithDuration here because UIScrollView doesn't let you control its deceleration rate.
        [UIView animateWithDuration:kFSCSwipeCellAnimationDuration
                         animations:^{
                             self.bounds = CGRectOffset(self.frame, x, 0);
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

#pragma mark UITableViewCell

- (void)prepareForReuse {
    [self setCurrentSide:FSCSwipeCellSideNone animated:NO];
}

#pragma mark UIView

- (void)willRemoveSubview:(UIView *)subview {
    if (_leftView == subview) _leftView = nil;
    if (_rightView == subview) _rightView = nil;
}

@end