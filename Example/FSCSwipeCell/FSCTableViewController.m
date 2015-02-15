#import "FSCTableViewController.h"

@interface FSCTableViewController ()

@property (nonatomic, strong) NSMutableArray *labels;

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
    cell.rightView.backgroundColor = [UIColor colorWithHue:0.2 saturation:1 brightness:MIN(0.5 + distance / 150, 1) alpha:1];
}

- (void)swipeCellDidChangeCurrentSide:(FSCSwipeCell *)cell {
    if (cell.currentSide == FSCSwipeCellSideRight) {
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
            cell.currentSide = FSCSwipeCellSideNone;
        }]];

        [self presentViewController:alert animated:YES completion:nil];
    }
}

#pragma mark UITableViewDataSource

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *cellId = @"randomCell";

    // For the purposes of this demo, just return a random cell.
    FSCSwipeCell *cell = [tableView dequeueReusableCellWithIdentifier:cellId];
    if (!cell) {
        cell = [[FSCSwipeCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:cellId];
        cell.delegate = self;
    }

    // Create the right view which will be our "Snooze" action.
    cell.rightView = [[UIView alloc] init];

    // Set up the labels.
    cell.detailTextLabel.text = @"Swipe right to archive, left to snooze.";
    cell.detailTextLabel.textColor = [UIColor grayColor];
    cell.textLabel.text = self.labels[indexPath.row];

    return cell;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [self.labels count];
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