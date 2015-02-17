#import "FSCSwipeCell.h"

CGFloat const kFSCSwipeCellAnimationDuration = 0.15;
CGFloat const kFSCSwipeCellOpenDistanceThreshold = 75;
CGFloat const kFSCSwipeCellOpenVelocityThreshold = 0.6;

FSCSwipeCell *FSCSwipeCellCurrentSwipingCell;

#pragma mark - FSCSwipeCell

@interface FSCSwipeCell ()

@property (nonatomic) BOOL ignoreSwiping;
@property (nonatomic) FSCSwipeCellSide lastShownSide;
@property (nonatomic, strong) UIScrollView *scrollView;

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
    // Create the scroll view which enables the horizontal swiping.
    UIScrollView *scrollView = [[UIScrollView alloc] initWithFrame:self.contentView.bounds];
    // Make the scroll view indicate that it's swipeable, even when it can't be swiped.
    scrollView.alwaysBounceHorizontal = YES;
    // Ensure that the scroll view has the same size as the cell.
    scrollView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    scrollView.contentSize = self.contentView.bounds.size;
    // Handle the behavior of the scroll view.
    scrollView.delegate = self;
    // Don't take control of the status bar tap-to-scroll-to-top functionality.
    scrollView.scrollsToTop = NO;
    // Don't create scroll indicators.
    scrollView.showsHorizontalScrollIndicator = NO;
    scrollView.showsVerticalScrollIndicator = NO;
    _scrollView = scrollView;

    // Remove the white background color from the cell itself.
    self.backgroundColor = [UIColor clearColor];

    // Inject the scroll view to contain the content view.
    UIView *contentView = self.contentView;
    [contentView.superview insertSubview:scrollView aboveSubview:contentView];
    [contentView removeFromSuperview];
    [scrollView addSubview:contentView];
    // Make the content view white since it can now uncover things behind it.
    contentView.backgroundColor = [UIColor whiteColor];
}

#pragma mark Properties

- (void)setCurrentSide:(FSCSwipeCellSide)side {
    [self setCurrentSide:side animated:YES];
}

- (void)setCurrentSide:(FSCSwipeCellSide)side animated:(BOOL)animated {
    if (side == _currentSide) {
        if (!animated) {
            dispatch_async(dispatch_get_main_queue(), ^{
                // Terminate any ongoing animation to make the change instant.
                [self.scrollView.layer removeAllAnimations];
            });
        }
        return;
    }

    _currentSide = side;
    [self setOffsetX:(self.scrollView.bounds.size.width * side) animated:animated];

    if ([self.delegate respondsToSelector:@selector(swipeCellDidChangeCurrentSide:)]) {
        [self.delegate swipeCellDidChangeCurrentSide:self];
    }
}

- (void)setLeftView:(UIView *)view {
    if (_leftView) {
        [_leftView removeFromSuperview];
    }

    _leftView = view;
    self.scrollView.contentInset = UIEdgeInsetsMake(0, (view ? self.scrollView.bounds.size.width : 0), 0, self.scrollView.contentInset.right);

    if (view) {
        [self insertSubview:view atIndex:0];
    }
}

- (void)setRightView:(UIView *)view {
    if (_rightView) {
        [_rightView removeFromSuperview];
    }

    _rightView = view;
    self.scrollView.contentInset = UIEdgeInsetsMake(0, self.scrollView.contentInset.left, 0, (view ? self.scrollView.bounds.size.width : 0));

    if (view) {
        [self insertSubview:view atIndex:0];
    }
}

#pragma mark Private methods

- (void)setOffsetX:(CGFloat)x animated:(BOOL)animated {
    CGPoint target = CGPointMake(x, 0);
    dispatch_async(dispatch_get_main_queue(), ^{
        if (!animated) {
            [self.scrollView setContentOffset:target animated:NO];
            return;
        }

        // We use animateWithDuration here because UIScrollView doesn't let you control its deceleration rate.
        [UIView animateWithDuration:kFSCSwipeCellAnimationDuration
                         animations:^{
                             [self.scrollView setContentOffset:target animated:NO];
                         }
                         completion:^(BOOL finished) {
                             if (self.leftView && self.currentSide != FSCSwipeCellSideLeft) {
                                 self.leftView.hidden = YES;
                             }

                             if (self.rightView && self.currentSide != FSCSwipeCellSideRight) {
                                 self.rightView.hidden = YES;
                             }
                         }];
    });
}

#pragma mark UIScrollViewDelegate

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    CGFloat x;
    if (self.ignoreSwiping) {
        // Another view is being swiped, so counteract swiping on this one.
        x = 0;
        [scrollView setContentOffset:CGPointZero animated:NO];
    } else {
        x = scrollView.contentOffset.x;
    }

    // Figure out which side will show.
    FSCSwipeCellSide side = (x < 0 ? FSCSwipeCellSideLeft : (x > 0 ? FSCSwipeCellSideRight : FSCSwipeCellSideNone));
    if (side != self.lastShownSide) {
        self.lastShownSide = side;
        if (side != FSCSwipeCellSideNone && [self.delegate respondsToSelector:@selector(swipeCell:shouldShowSide:)]) {
            // Ask the delegate if the side should show.
            if (![self.delegate swipeCell:self shouldShowSide:side]) {
                // Cancel the swipe.
                [scrollView setContentOffset:CGPointZero animated:NO];
                return;
            }
        }
    }

    // Update the visibility of the left/right swipe views.
    if (x != 0 || scrollView.dragging) {
        if (self.leftView) self.leftView.hidden = (x >= 0);
        if (self.rightView) self.rightView.hidden = (x <= 0);
    }

    // Let the delegate know that the cell was swiped.
    if ([self.delegate respondsToSelector:@selector(swipeCell:didSwipe:side:)]) {
        if ((side == FSCSwipeCellSideLeft && self.leftView) || (side == FSCSwipeCellSideRight && self.rightView)) {
            [self.delegate swipeCell:self didSwipe:abs(x) side:side];
        }
    }
}

- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView {
    @synchronized([FSCSwipeCell class]) {
        if (FSCSwipeCellCurrentSwipingCell) {
            // Another cell is already being swiped.
            self.ignoreSwiping = YES;
            return;
        }
        FSCSwipeCellCurrentSwipingCell = self;
        self.lastShownSide = FSCSwipeCellSideNone;
        self.ignoreSwiping = NO;
    }

    CGRect frame = CGRectMake(0, 0, self.scrollView.bounds.size.width, self.scrollView.bounds.size.height);
    if (self.leftView) self.leftView.frame = frame;
    if (self.rightView) self.rightView.frame = frame;
}

- (void)scrollViewWillEndDragging:(UIScrollView *)scrollView withVelocity:(CGPoint)velocity targetContentOffset:(inout CGPoint *)targetContentOffset {
    @synchronized([FSCSwipeCell class]) {
        if (self.ignoreSwiping) {
            // This cell was probably swiped in a multi-touch gesture.
            return;
        }
        FSCSwipeCellCurrentSwipingCell = nil;
    }

    CGFloat x = scrollView.contentOffset.x, width = scrollView.bounds.size.width;
    BOOL goingLeft = (velocity.x > kFSCSwipeCellOpenVelocityThreshold);
    BOOL goingRight = (velocity.x < -kFSCSwipeCellOpenVelocityThreshold);

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
        [self setOffsetX:self.currentSide * width animated:YES];
    }
}

#pragma mark UITableViewCell

- (void)prepareForReuse {
    [self setCurrentSide:FSCSwipeCellSideNone animated:NO];
}

#pragma mark UIView

- (void)layoutSubviews {
    [super layoutSubviews];
    if (CGSizeEqualToSize(self.scrollView.contentSize, self.contentView.bounds.size)) {
        return;
    }
    // This is necessary to ensure that the content size scales with the view.
    self.scrollView.contentSize = self.contentView.bounds.size;
    self.scrollView.contentOffset = CGPointZero;
    // Update the insets to reflect the new size.
    CGFloat width = self.scrollView.bounds.size.width;
    self.scrollView.contentInset = UIEdgeInsetsMake(0, (self.leftView ? width : 0), 0, (self.rightView ? width : 0));
}

@end