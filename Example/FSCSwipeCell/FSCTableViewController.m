#import "FSCTableViewController.h"

@interface FSCTableViewController ()

@property (nonatomic, strong) NSMutableArray *labels;
@property (nonatomic, weak) FSCSwipeCell *optionsCell;

@end

@implementation FSCTableViewController

- (void)viewDidLoad {
    self.labels = [NSMutableArray arrayWithObjects:@"Pippi Longstocking", @"Austin Powers", @"Spider-Man", @"James Bond",
                                                   @"Lisbeth Salander", @"Donald Duck", @"Luke Skywalker", @"Lara Croft",
                                                   @"Frodo Baggins", @"Hermione Granger", @"Dexter Morgan", @"Ted Mosby",
                                                   @"Homer Simpson", @"John Connor", @"Arya Stark", @"Captain Kirk", nil];
}

#pragma mark FSCSwipeCellDelegate

- (void)swipeCell:(FSCSwipeCell *)cell didScroll:(CGFloat)distance side:(FSCSwipeCellSide)side {
    // Calculate a brightness based on how far the cell has been swiped (hits 1.0 when cell will open on its own when released).
    CGFloat brightness = MIN(0.5 + distance / (kFSCSwipeCellOpenDistanceThreshold * 2), 1);

    if (side == FSCSwipeCellSideLeft) {
        cell.leftView.backgroundColor = [UIColor colorWithHue:0.8 saturation:1 brightness:brightness alpha:1];
    } else if (side == FSCSwipeCellSideRight) {
        cell.rightView.backgroundColor = [UIColor colorWithHue:0.2 saturation:1 brightness:brightness alpha:1];
    }
}

- (void)swipeCellDidChangeCurrentSide:(FSCSwipeCell *)cell {
    switch (cell.currentSide) {
        case FSCSwipeCellSideLeft:
            // This is now the cell showing options.
            self.optionsCell = cell;
            break;
        case FSCSwipeCellSideNone:
            if (cell == self.optionsCell) {
                // The cell is no longer open.
                self.optionsCell = nil;
            }
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

- (BOOL)swipeCell:(FSCSwipeCell *)cell shouldShowSide:(FSCSwipeCellSide)side {
    if (side == FSCSwipeCellSideLeft && self.optionsCell && cell != self.optionsCell) {
        // We only want to display one cell with options at the time. Close the other one first.
        self.optionsCell.currentSide = FSCSwipeCellSideNone;
        return NO;
    }

    return YES;
}

#pragma mark UITableViewDataSource

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *cellId = @"randomCell";

    // For the purposes of this demo, just return a random cell.
    FSCSwipeCell *cell = [tableView dequeueReusableCellWithIdentifier:cellId];
    if (!cell) {
        cell = [[FSCSwipeCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:cellId];
        cell.delegate = self;

        // Create the left view which will contain options.
        cell.leftView = [[UIView alloc] init];

        // Create the right view which will be our "Snooze" action.
        cell.rightView = [[UIView alloc] init];
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