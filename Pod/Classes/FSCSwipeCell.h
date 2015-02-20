#import <UIKit/UIKit.h>

@class FSCSwipeCell;

/**
 * Refers to a particular side of a cell.
 */
typedef NS_ENUM(NSInteger, FSCSwipeCellSide) {
    /** Neither side of the cell, often referring to the cell being in its default state. */
    FSCSwipeCellSideNone = 0,
    /** The left side of the cell. */
    FSCSwipeCellSideLeft = -1,
    /** The right side of the cell. */
    FSCSwipeCellSideRight = 1,
};

/**
 * The duration of the cell's open/close animations, in seconds.
 */
extern CGFloat const kFSCSwipeCellAnimationDuration;

/**
 * How many points the user has to swipe the cell in a direction to open when the user lets
 * go of the cell.
 */
extern CGFloat const kFSCSwipeCellOpenDistanceThreshold;

/**
 * The minimum velocity required to perform an action if released before the threshold has
 * been passed.
 */
extern CGFloat const kFSCSwipeCellOpenVelocityThreshold;

#pragma mark - FSCSwipeCellDelegate

/**
 * Allows monitoring and some control of the user's interaction with the cell.
 */
@protocol FSCSwipeCellDelegate <NSObject>

@optional
/**
 * Called when the left/right side view of the cell is no longer visible.
 */
- (void)swipeCell:(FSCSwipeCell *)cell didHideSide:(FSCSwipeCellSide)side;
/**
 * Called whenever the cell is being swiped by the user.
 */
- (void)swipeCell:(FSCSwipeCell *)cell didSwipe:(CGFloat)distance side:(FSCSwipeCellSide)side;
/**
 * Called before a left/right side view is shown, allowing the swipe to be ignored.
 */
- (BOOL)swipeCell:(FSCSwipeCell *)cell shouldShowSide:(FSCSwipeCellSide)side;
/**
 * Called when the current side of the cell changes. This will be called before animations
 * complete.
 */
- (void)swipeCellDidChangeCurrentSide:(FSCSwipeCell *)cell;

@end

#pragma mark - FSCSwipeCell

/**
 * Table view cells of this class will reveal a colored area that represents an action when
 * the user swipes left or right on the cell. If the user passes over a certain threshold,
 * the action will be triggered; otherwise, the cell will just bounce back to its default
 * state.
 */
@interface FSCSwipeCell : UITableViewCell <UIScrollViewDelegate>

/**
 * The currently shown side of the cell. Note that this value will change before the animation
 * finishes.
 */
@property (nonatomic) FSCSwipeCellSide currentSide;
/**
 * An optional delegate which will be notified whenever the user interacts with the cell.
 */
@property (nonatomic, weak) id<FSCSwipeCellDelegate> delegate;
/**
 * The view to display when the cell is swiped from left to right. Setting this value will put
 * the specified view as a subview of this cell. Removing that view from this cell will reset
 * this value to nil.
 */
@property (nonatomic, strong) UIView *leftView;
/**
 * The view to display when the cell is swiped from right to left. Setting this value will put
 * the specified view as a subview of this cell. Removing that view from this cell will reset
 * this value to nil.
 */
@property (nonatomic, strong) UIView *rightView;
/**
 * The scroll view which enables the content of the cell to move left and right over the
 * subviews.
 */
@property (nonatomic, readonly, strong) UIScrollView *scrollView;

/**
 * Sets the current side of the cell, with control over animation. By default, the side change
 * is animated, but passing in NO will make the change instant.
 */
- (void)setCurrentSide:(FSCSwipeCellSide)side animated:(BOOL)animated;

@end