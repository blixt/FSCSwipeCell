#import <UIKit/UIKit.h>

@class FSCSwipeCell;

/**
 * Refers to a particular side of a cell.
 */
typedef NS_ENUM(NSUInteger, FSCSwipeCellSide) {
    FSCSwipeCellSideNone,
    FSCSwipeCellSideLeft,
    FSCSwipeCellSideRight,
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
 * TODO
 */
@protocol FSCSwipeCellDelegate <NSObject>

@optional
- (void)swipeCell:(FSCSwipeCell *)cell didChangeCurrentSide:(FSCSwipeCellSide)newSide;
- (BOOL)swipeCell:(FSCSwipeCell *)cell shouldChangeCurrentSide:(FSCSwipeCellSide)newSide;
- (void)swipeCell:(FSCSwipeCell *)cell willShowSide:(FSCSwipeCellSide)side;

@end

#pragma mark - FSCSwipeCell

/**
 * Table view cells of this class will reveal a colored area that represents an action when
 * the user swipes left or right on the cell. If the user passes over a certain threshold,
 * the action will be triggered; otherwise, the cell will just bounce back to its default
 * state.
 */
@interface FSCSwipeCell : UITableViewCell <UIScrollViewDelegate>

@property (nonatomic, readonly) FSCSwipeCellSide currentSide;
@property (nonatomic, weak) id<FSCSwipeCellDelegate> delegate;
@property (nonatomic, strong) UIView *leftView;
@property (nonatomic, strong) UIView *rightView;
@property (nonatomic, readonly, strong) UIScrollView *scrollView;

@end