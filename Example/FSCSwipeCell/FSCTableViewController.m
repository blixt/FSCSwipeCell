#import "FSCSwipeCell/FSCSwipeCell.h"

#import "FSCTableViewController.h"

@interface FSCTableViewController ()

@property (nonatomic, strong) NSArray *labels;

@end

@implementation FSCTableViewController

- (void)viewDidLoad {
    self.labels = @[@"Pippi Longstocking", @"Austin Powers", @"Spider-Man", @"James Bond",
                    @"Lisbeth Salander", @"Donald Duck", @"Luke Skywalker", @"Lara Croft",
                    @"Frodo Baggins", @"Hermione Granger", @"Dexter Morgan", @"Ted Mosby",
                    @"Homer Simpson", @"John Connor", @"Arya Stark", @"Captain Kirk"];
}

#pragma mark UITableViewDataSource

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *cellId = @"randomCell";

    // For the purposes of this demo, just return a random cell.
    FSCSwipeCell *cell = [tableView dequeueReusableCellWithIdentifier:cellId];
    if (!cell) {
        cell = [[FSCSwipeCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:cellId];
    }

    cell.leftView = [[UIView alloc] init];
    cell.leftView.backgroundColor = [UIColor greenColor];

    cell.detailTextLabel.text = @"Swipe me!";
    cell.detailTextLabel.textColor = [UIColor grayColor];
    
    cell.textLabel.text = self.labels[indexPath.row];

    return cell;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [self.labels count];
}

#pragma mark UITableViewDelegate

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 50;
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