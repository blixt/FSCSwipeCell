#import "FSCSwipeCell.h"

CGFloat const kFSCSwipeCellAnimationDuration = 0.2;
CGFloat const kFSCSwipeCellOpenDistanceThreshold = 75;
CGFloat const kFSCSwipeCellOpenVelocityThreshold = 0.6;

#pragma mark - FSCSwipeCell

@interface FSCSwipeCell ()

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

    CGPoint target = CGPointMake(self.scrollView.bounds.size.width * side, 0);
    dispatch_async(dispatch_get_main_queue(), ^{
        if (!animated) {
            [self.scrollView setContentOffset:target animated:NO];

            if ([self.delegate respondsToSelector:@selector(swipeCellDidChangeCurrentSide:)]) {
                [self.delegate swipeCellDidChangeCurrentSide:self];
            }

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

                             if ([self.delegate respondsToSelector:@selector(swipeCellDidChangeCurrentSide:)]) {
                                 [self.delegate swipeCellDidChangeCurrentSide:self];
                             }
                         }];
    });
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

#pragma mark UIScrollViewDelegate

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    CGFloat x = scrollView.contentOffset.x;

    FSCSwipeCellSide side = (x < 0 ? FSCSwipeCellSideLeft : (x > 0 ? FSCSwipeCellSideRight : FSCSwipeCellSideNone));
    if (side != FSCSwipeCellSideNone && [self.delegate respondsToSelector:@selector(swipeCell:shouldShowSide:)]) {
        if (![self.delegate swipeCell:self shouldShowSide:side]) {
            // Cancel the scroll.
            scrollView.contentOffset = CGPointZero;
            return;
        }
    }

    if (x != 0 || scrollView.isDragging) {
        if (self.leftView) self.leftView.hidden = (x >= 0);
        if (self.rightView) self.rightView.hidden = (x <= 0);
    }

    if ([self.delegate respondsToSelector:@selector(swipeCell:didScroll:side:)]) {
        if ((side == FSCSwipeCellSideLeft && self.leftView) || (side == FSCSwipeCellSideRight && self.rightView)) {
            [self.delegate swipeCell:self didScroll:abs(x) side:side];
        }
    }
}

- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView {
    CGRect frame = CGRectMake(0, 0, self.scrollView.bounds.size.width, self.scrollView.bounds.size.height);
    if (self.leftView) self.leftView.frame = frame;
    if (self.rightView) self.rightView.frame = frame;
}

- (void)scrollViewWillEndDragging:(UIScrollView *)scrollView withVelocity:(CGPoint)velocity targetContentOffset:(inout CGPoint *)targetContentOffset {
    CGFloat x = scrollView.contentOffset.x, width = scrollView.bounds.size.width;
    BOOL goingLeft = (velocity.x < -kFSCSwipeCellOpenVelocityThreshold);
    BOOL goingRight = (velocity.x > kFSCSwipeCellOpenVelocityThreshold);

    switch (self.currentSide) {
        case FSCSwipeCellSideLeft:
            // Return to default state unless the user swiped in the open direction.
            if (!goingLeft && x > -width) {
                self.currentSide = FSCSwipeCellSideNone;
            }
            break;
        case FSCSwipeCellSideNone:
            // Open the relevant side (if it has a style and the user dragged beyond the threshold).
            if (goingLeft || (x < -kFSCSwipeCellOpenDistanceThreshold && !goingRight)) {
                self.currentSide = self.leftView ? FSCSwipeCellSideLeft : FSCSwipeCellSideNone;
            } else if (goingRight || (x > kFSCSwipeCellOpenDistanceThreshold && !goingLeft)) {
                self.currentSide = self.rightView ? FSCSwipeCellSideRight : FSCSwipeCellSideNone;
            }
            break;
        case FSCSwipeCellSideRight:
            // Return to default state unless the user swiped in the open direction.
            if (!goingRight && x < width) {
                self.currentSide = FSCSwipeCellSideNone;
            }
            break;
    }

    targetContentOffset->x = width * self.currentSide;
}

#pragma mark UITableViewCell

- (void)prepareForReuse {
    [self setCurrentSide:FSCSwipeCellSideNone animated:NO];
    self.leftView = nil;
    self.rightView = nil;
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