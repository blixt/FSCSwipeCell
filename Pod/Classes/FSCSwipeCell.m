#import "FSCSwipeCell.h"

CGFloat const kFSCSwipeCellAnimationDuration = 0.15;
CGFloat const kFSCSwipeCellOpenDistanceThreshold = 70;
CGFloat const kFSCSwipeCellOpenVelocityThreshold = 0.6;

#pragma mark - FSCSwipeCell

@interface FSCSwipeCell ()

@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic) CGFloat targetScrollX;

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

- (FSCSwipeCellSide)currentSide {
    if (self.targetScrollX < 0) {
        return FSCSwipeCellSideLeft;
    } else if (self.targetScrollX > 0) {
        return FSCSwipeCellSideRight;
    } else {
        return FSCSwipeCellSideNone;
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

#pragma mark UIScrollViewDelegate

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    if (!scrollView.isDragging) return;
    if (self.leftView) self.leftView.hidden = (scrollView.contentOffset.x >= 0);
    if (self.rightView) self.rightView.hidden = (scrollView.contentOffset.x <= 0);
}

- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView {
    CGRect frame = CGRectMake(0, 0, self.scrollView.bounds.size.width, self.scrollView.bounds.size.height);
    if (self.leftView) self.leftView.frame = frame;
    if (self.rightView) self.rightView.frame = frame;
}

- (void)scrollViewWillEndDragging:(UIScrollView *)scrollView withVelocity:(CGPoint)velocity targetContentOffset:(inout CGPoint *)targetContentOffset {
    CGFloat x = scrollView.contentOffset.x, width = scrollView.bounds.size.width;
    BOOL goingLeft = (x < 0 && velocity.x < -kFSCSwipeCellOpenVelocityThreshold);
    BOOL goingRight = (x > 0 && velocity.x > kFSCSwipeCellOpenVelocityThreshold);

    switch (self.currentSide) {
        case FSCSwipeCellSideLeft:
            // Return to default state unless the user swiped in the open direction.
            if (!goingLeft && x > -width) {
                self.targetScrollX = 0;
            }
            break;
        case FSCSwipeCellSideNone:
            // Open the relevant side (if it has a style and the user dragged beyond the threshold).
            if (goingLeft || x < -kFSCSwipeCellOpenDistanceThreshold) {
                self.targetScrollX = self.leftView ? -width : 0;
            } else if (goingRight || x > kFSCSwipeCellOpenDistanceThreshold) {
                self.targetScrollX = self.rightView ? width : 0;
            }
            break;
        case FSCSwipeCellSideRight:
            // Return to default state unless the user swiped in the open direction.
            if (!goingRight && x < width) {
                self.targetScrollX = 0;
            }
            break;
    }

    targetContentOffset->x = self.targetScrollX;

    // We use animateWithDuration here because UIScrollView doesn't let you control its deceleration rate.
    dispatch_async(dispatch_get_main_queue(), ^{
        [UIView animateWithDuration:kFSCSwipeCellAnimationDuration
                         animations:^{
                             [scrollView setContentOffset:CGPointMake(self.targetScrollX, 0) animated:NO];
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

#pragma mark UITableViewCell

- (void)prepareForReuse {
    self.leftView = nil;
    self.rightView = nil;
}

#pragma mark UIView

- (void)layoutSubviews {
    [super layoutSubviews];
    // This is necessary to ensure that the content size scales with the view.
    self.scrollView.contentSize = self.contentView.bounds.size;
    self.scrollView.contentOffset = CGPointZero;
    CGFloat width = self.scrollView.bounds.size.width;
    self.scrollView.contentInset = UIEdgeInsetsMake(0, (self.leftView ? width : 0), 0, (self.rightView ? width : 0));
}

@end