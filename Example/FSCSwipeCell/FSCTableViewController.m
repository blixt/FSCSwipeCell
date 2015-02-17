#import "FSCTableViewController.h"

@interface FSCTableViewController ()

@property (nonatomic, strong) NSMutableArray *labels;
@property (nonatomic, weak) FSCSwipeCell *optionsCell;
@property (nonatomic, strong) UIView *optionsView;

@end

/**
 * This example aims to show the versatility of FSCSwipeView. While FSCSwipeView does very little on its own,
 * it's pretty easy to implement your own logic on top of it to get swipable table view cells that behave as
 * you'd expect.
 *
 * The main ideas shown in this example are:
 * - Cells that can be swiped left and right without interfering with normal scrolling;
 * - Swipe-to-perform-action cells (a la Google's Inbox);
 * - Swipe to reveal option buttons;
 * - Reuse a single option buttons view for all cells;
 * - Dynamic background and iconography to indicate to the user how far to swipe
 */
@implementation FSCTableViewController

- (void)viewDidLoad {
    // Create the options view which will be shared by all cells (instead of recreating it for every cell).
    self.optionsView = [[UIView alloc] init];

    // Create an array which contains a bunch of names that we'll use as example data.
    self.labels = [NSMutableArray arrayWithObjects:@"Pippi Longstocking", @"Austin Powers", @"Spider-Man", @"James Bond",
                                                   @"Lisbeth Salander", @"Donald Duck", @"Luke Skywalker", @"Lara Croft",
                                                   @"Frodo Baggins", @"Hermione Granger", @"Dexter Morgan", @"Ted Mosby",
                                                   @"Homer Simpson", @"John Connor", @"Arya Stark", @"Captain Kirk", nil];
}

#pragma mark FSCSwipeCellDelegate

- (void)swipeCell:(FSCSwipeCell *)cell didSwipe:(CGFloat)distance side:(FSCSwipeCellSide)side {
    // This method is called when a cell is being swiped by the user. The distance is always a positive number.

    // Calculate the progress (0.0-1.0) until releasing the cell will perform the action.
    CGFloat progressToAction = MIN(distance / kFSCSwipeCellOpenDistanceThreshold, 1);

    // Calculate a brightness based on how far the cell has been swiped.
    CGFloat brightness = 0.5 + progressToAction / 2;
    if (side == FSCSwipeCellSideLeft) {
        cell.leftView.backgroundColor = [UIColor colorWithHue:0.6 saturation:0.4 brightness:brightness alpha:1];
    } else if (side == FSCSwipeCellSideRight) {
        cell.rightView.backgroundColor = [UIColor colorWithHue:0.12 saturation:1 brightness:brightness alpha:1];

        // Place the snooze icon with the correct size.
        UIImageView *snooze = (UIImageView *)[cell.rightView viewWithTag:1];
        if (progressToAction > 0.5) {
            CGFloat size = 16 * (progressToAction * 2 - 1);
            snooze.frame = CGRectMake(0, 0, size, size);
            snooze.center = CGPointMake(cell.bounds.size.width - 30, cell.bounds.size.height / 2);
            snooze.hidden = NO;
        } else {
            snooze.hidden = YES;
        }
    }
}

- (void)swipeCellDidChangeCurrentSide:(FSCSwipeCell *)cell {
    // This method is called whenever the open side changed. Note that this happens before animations finish.
    switch (cell.currentSide) {
        case FSCSwipeCellSideLeft:
            // This is now the cell showing options.
            self.optionsCell = cell;
            break;
        case FSCSwipeCellSideNone:
            break;
        case FSCSwipeCellSideRight:
        {
            // Show the snooze menu (all the code below but one line is for showing the iOS alert).
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Snooze"
                                                                           message:@"How long do you want to snooze?"
                                                                    preferredStyle:UIAlertControllerStyleActionSheet];

            // This is only used by iPad.
            UIPopoverPresentationController *popover = alert.popoverPresentationController;
            if (popover) {
                popover.sourceView = cell;
                popover.sourceRect = cell.bounds;
                popover.permittedArrowDirections = UIPopoverArrowDirectionAny;
            }

            // This is the block that we will run if the user picks an option.
            void (^remove)(UIAlertAction *) = ^void(UIAlertAction *action) {
                // Don't do this at home, kids.
                NSUInteger index = [self.labels indexOfObject:cell.textLabel.text];
                // Remove the row from view.
                [self.labels removeObjectAtIndex:index];
                [self.tableView deleteRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:index inSection:0]]
                                      withRowAnimation:UITableViewRowAnimationAutomatic];
            };

            [alert addAction:[UIAlertAction actionWithTitle:@"5 minutes" style:UIAlertActionStyleDefault handler:remove]];
            [alert addAction:[UIAlertAction actionWithTitle:@"One hour" style:UIAlertActionStyleDefault handler:remove]];
            [alert addAction:[UIAlertAction actionWithTitle:@"Until tomorrow" style:UIAlertActionStyleDefault handler:remove]];

            // If the user cancels, simply reset the cell.
            [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:^(UIAlertAction *action) {
                // This line is the only FSCSwipeCell-related code for snoozing. It will "close" the open cell.
                cell.currentSide = FSCSwipeCellSideNone;
            }]];

            [self presentViewController:alert animated:YES completion:nil];
            break;
        }
    }
}

- (void)swipeCell:(FSCSwipeCell *)cell didHideSide:(FSCSwipeCellSide)side {
    // This method is called after a side is no longer visible (after animations).
    if (side == FSCSwipeCellSideLeft && cell == self.optionsCell) {
        // The cell is no longer open.
        self.optionsCell = nil;
    }
}

- (BOOL)swipeCell:(FSCSwipeCell *)cell shouldShowSide:(FSCSwipeCellSide)side {
    // This method is called before a side starts showing, giving you the opportunity to cancel the swipe.
    if (self.optionsCell && cell != self.optionsCell) {
        // We only want to display one cell with options at the time. Close the other one first.
        self.optionsCell.currentSide = FSCSwipeCellSideNone;
        // Keep the left side closed until the other cell has finished closing.
        if (side == FSCSwipeCellSideLeft) {
            return NO;
        }
    }

    // We're about to show the left side - move the options view to this cell.
    if (side == FSCSwipeCellSideLeft) {
        cell.leftView = self.optionsView;
    }

    return YES;
}

#pragma mark UITableViewDataSource

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *cellId = @"randomCell";

    // Either reuse an existing cell or set up a new one if necessary.
    FSCSwipeCell *cell = [tableView dequeueReusableCellWithIdentifier:cellId];
    if (!cell) {
        // Note: We won't create the left view here because it'll be shared by all cells.
        cell = [[FSCSwipeCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:cellId];
        cell.delegate = self;

        // Create the right view which will be our "Snooze" action.
        cell.rightView = [[UIView alloc] init];

        // Create an image view for the Snooze icon.
        UIImageView *snooze = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"Snooze"]];
        snooze.tag = 1;
        [cell.rightView addSubview:snooze];
    }

    // Set up the labels.
    cell.detailTextLabel.text = @"Swipe right for options, left to snooze.";
    cell.detailTextLabel.textColor = [UIColor grayColor];
    cell.textLabel.text = self.labels[indexPath.row];

    return cell;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [self.labels count];
}

#pragma mark UIScrollViewDelegate

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    for (FSCSwipeCell *cell in [self.tableView visibleCells]) {
        cell.currentSide = FSCSwipeCellSideNone;
    }
}

#pragma mark UITableViewDelegate

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 60;
}

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath {
    // Remove insets and margins from cells.
    if ([cell respondsToSelector:@selector(setSeparatorInset:)]) {
        [cell setSeparatorInset:UIEdgeInsetsZero];
    }

    if ([cell respondsToSelector:@selector(setPreservesSuperviewLayoutMargins:)]) {
        [cell setPreservesSuperviewLayoutMargins:NO];
    }

    if ([cell respondsToSelector:@selector(setLayoutMargins:)]) {
        [cell setLayoutMargins:UIEdgeInsetsZero];
    }
}

@end