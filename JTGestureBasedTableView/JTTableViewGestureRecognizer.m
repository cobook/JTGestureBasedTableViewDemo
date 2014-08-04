/*
 * This file is part of the JTGestureBasedTableView package.
 * (c) James Tang <mystcolor@gmail.com>
 *
 * For the full copyright and license information, please view the LICENSE
 * file that was distributed with this source code.
 */

#import "JTTableViewGestureRecognizer.h"
#import <QuartzCore/QuartzCore.h>


CGFloat const JTTableViewRowAnimationDuration          = 0.25;       // Rough guess is 0.25

@interface JTTableViewGestureRecognizer () <UIGestureRecognizerDelegate>
@property (nonatomic, weak) id <JTTableViewGestureMoveRowDelegate> delegate;
@property (nonatomic, weak) id <UITableViewDelegate>         tableViewDelegate;
@property (nonatomic, weak) UITableView                     *tableView;
@property (nonatomic, strong) NSIndexPath                   *addingIndexPath;
@property (nonatomic, strong) UILongPressGestureRecognizer  *longPressRecognizer;
@property (nonatomic, assign) CGFloat                        scrollingRate;
@property (nonatomic, strong) NSTimer                       *movingTimer;

- (void)updateAddingIndexPathForCurrentLocation;

@end

#define CELL_SNAPSHOT_TAG 100000

@implementation JTTableViewGestureRecognizer

- (void)scrollTable {
    // Scroll tableview while touch point is on top or bottom part

    CGPoint location        = CGPointZero;
    // Refresh the indexPath since it may change while we use a new offset
    location  = [self.longPressRecognizer locationInView:self.tableView];

    CGPoint currentOffset = self.tableView.contentOffset;
    CGPoint newOffset = CGPointMake(currentOffset.x, currentOffset.y + self.scrollingRate);
    CGFloat top = -self.tableView.contentInset.top;
    if (newOffset.y < top) {
        newOffset.y = top;
    } else if (self.tableView.contentSize.height < self.tableView.frame.size.height) {
        newOffset = currentOffset;
    } else if (newOffset.y > self.tableView.contentSize.height - self.tableView.frame.size.height) {
        newOffset.y = self.tableView.contentSize.height - self.tableView.frame.size.height;
    }
    [self.tableView setContentOffset:newOffset];
    
    if (location.y >= 0) {
        UIImageView *cellSnapshotView = (id)[self.tableView viewWithTag:CELL_SNAPSHOT_TAG];
        cellSnapshotView.center = CGPointMake(self.tableView.center.x, location.y);
    }
    
    [self updateAddingIndexPathForCurrentLocation];
}

- (void)updateAddingIndexPathForCurrentLocation {
    NSIndexPath *indexPath  = nil;
    CGPoint location        = CGPointZero;

    // Refresh the indexPath since it may change while we use a new offset
    location  = [self.longPressRecognizer locationInView:self.tableView];
    indexPath = [self.tableView indexPathForRowAtPoint:location];

    if (indexPath && ! [indexPath isEqual:self.addingIndexPath]) {
      if ([self.delegate respondsToSelector:@selector(gestureRecognizer:canMoveRowAtIndexPath:toIndexPath:)]) {
        if (![self.delegate gestureRecognizer:self canMoveRowAtIndexPath:self.addingIndexPath toIndexPath:indexPath]) {
          return;
        }
      }

      [self.tableView beginUpdates];
      [self.tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:self.addingIndexPath] withRowAnimation:UITableViewRowAnimationNone];
      [self.tableView insertRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:UITableViewRowAnimationNone];
      [self.delegate gestureRecognizer:self needsMoveRowAtIndexPath:self.addingIndexPath toIndexPath:indexPath];

      self.addingIndexPath = indexPath;

      [self.tableView endUpdates];
    }
}


#pragma mark Action


- (void)longPressGestureRecognizer:(UILongPressGestureRecognizer *)recognizer {
    CGPoint location = [recognizer locationInView:self.tableView];
    NSIndexPath *indexPath = [self.tableView indexPathForRowAtPoint:location];

    if (recognizer.state == UIGestureRecognizerStateBegan) {
        UITableViewCell *cell = [self.tableView cellForRowAtIndexPath:indexPath];
        UIGraphicsBeginImageContextWithOptions(cell.bounds.size, NO, 0);
        [cell.layer renderInContext:UIGraphicsGetCurrentContext()];
        UIImage *cellImage = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();

        // We create an imageView for caching the cell snapshot here
        UIImageView *snapShotView = (UIImageView *)[self.tableView viewWithTag:CELL_SNAPSHOT_TAG];
        if ( ! snapShotView) {
            snapShotView = [[UIImageView alloc] initWithImage:cellImage];
            snapShotView.tag = CELL_SNAPSHOT_TAG;
            [self.tableView addSubview:snapShotView];
            CGRect rect = [self.tableView rectForRowAtIndexPath:indexPath];
            snapShotView.frame = CGRectOffset(snapShotView.bounds, rect.origin.x, rect.origin.y);
        }
        // Make a zoom in effect for the cell
        [UIView beginAnimations:@"zoomCell" context:nil];
        snapShotView.transform = CGAffineTransformMakeScale(1.1, 1.1);
        snapShotView.center = CGPointMake(self.tableView.center.x, location.y);
        [UIView commitAnimations];

        [self.tableView beginUpdates];
        [self.tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:UITableViewRowAnimationNone];
        [self.tableView insertRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:UITableViewRowAnimationNone];
        [self.delegate gestureRecognizer:self needsCreatePlaceholderForRowAtIndexPath:indexPath];
        
        self.addingIndexPath = indexPath;

        [self.tableView endUpdates];

        // Start timer to prepare for auto scrolling
        self.movingTimer = [NSTimer timerWithTimeInterval:1/8 target:self selector:@selector(scrollTable) userInfo:nil repeats:YES];
        [[NSRunLoop mainRunLoop] addTimer:self.movingTimer forMode:NSDefaultRunLoopMode];

    } else if (recognizer.state == UIGestureRecognizerStateEnded) {
        // While long press ends, we remove the snapshot imageView
        
        __block __weak UIImageView *snapShotView = (UIImageView *)[self.tableView viewWithTag:CELL_SNAPSHOT_TAG];
        __block __weak JTTableViewGestureRecognizer *weakSelf = self;
        
        // We use self.addingIndexPath directly to make sure we dropped on a valid indexPath
        // which we've already ensure while UIGestureRecognizerStateChanged
        __block __weak NSIndexPath *indexPath = self.addingIndexPath;
        
        // Stop timer
        [self.movingTimer invalidate]; self.movingTimer = nil;
        self.scrollingRate = 0;

        [UIView animateWithDuration:JTTableViewRowAnimationDuration
                         animations:^{
                             CGRect rect = [weakSelf.tableView rectForRowAtIndexPath:indexPath];
                             snapShotView.transform = CGAffineTransformIdentity;    // restore the transformed value
                             snapShotView.frame = CGRectOffset(snapShotView.bounds, rect.origin.x, rect.origin.y);
                         } completion:^(BOOL finished) {
                             [snapShotView removeFromSuperview];
                           
                             [weakSelf.tableView beginUpdates];
                             [weakSelf.tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:UITableViewRowAnimationNone];
                             [weakSelf.tableView insertRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:UITableViewRowAnimationNone];
                             [weakSelf.delegate gestureRecognizer:weakSelf needsReplacePlaceholderForRowAtIndexPath:indexPath];
                             [weakSelf.tableView endUpdates];
                             [weakSelf.tableView reloadVisibleRowsExceptIndexPath:indexPath];
                             // Update state and clear instance variables
                             weakSelf.addingIndexPath = nil;
                         }];


    } else if (recognizer.state == UIGestureRecognizerStateChanged) {
        // While our finger moves, we also moves the snapshot imageView
        UIImageView *snapShotView = (UIImageView *)[self.tableView viewWithTag:CELL_SNAPSHOT_TAG];
        snapShotView.center = CGPointMake(self.tableView.center.x, location.y);

        CGRect rect      = self.tableView.bounds;
        CGPoint location = [self.longPressRecognizer locationInView:self.tableView];
        location.y -= self.tableView.contentOffset.y;       // We needed to compensate actual contentOffset.y to get the relative y position of touch.
        
        [self updateAddingIndexPathForCurrentLocation];
        
        CGFloat bottomDropZoneHeight = self.tableView.bounds.size.height / 6;
        CGFloat topDropZoneHeight    = bottomDropZoneHeight;
        CGFloat bottomDiff = location.y - (rect.size.height - bottomDropZoneHeight);
        if (bottomDiff > 0) {
            self.scrollingRate = bottomDiff / (bottomDropZoneHeight / 1);
        } else if (location.y <= topDropZoneHeight) {
            self.scrollingRate = -(topDropZoneHeight - MAX(location.y, 0)) / bottomDropZoneHeight;
        } else {
            self.scrollingRate = 0;
        }
    }
}

#pragma mark UIGestureRecognizer

- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer {
    if (gestureRecognizer == self.longPressRecognizer) {
        
        CGPoint location = [gestureRecognizer locationInView:self.tableView];
        NSIndexPath *indexPath = [self.tableView indexPathForRowAtPoint:location];

        if (indexPath && [self.delegate conformsToProtocol:@protocol(JTTableViewGestureMoveRowDelegate)]) {
            BOOL canMoveRow = [self.delegate gestureRecognizer:self canMoveRowAtIndexPath:indexPath];
            return canMoveRow;
        }
        return NO;
    }
    return YES;
}

#pragma mark UITableViewDelegate

- (CGFloat)tableView:(UITableView *)aTableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
  return [self.tableViewDelegate respondsToSelector:@selector(tableView:heightForRowAtIndexPath:)]
      ? [self.tableViewDelegate tableView:aTableView heightForRowAtIndexPath:indexPath]
      : aTableView.rowHeight;
}

#pragma mark NSProxy

- (void)forwardInvocation:(NSInvocation *)anInvocation {
    [anInvocation invokeWithTarget:self.tableViewDelegate];
}

- (NSMethodSignature *)methodSignatureForSelector:(SEL)aSelector {
    return [(NSObject *)self.tableViewDelegate methodSignatureForSelector:aSelector];
}

- (BOOL)respondsToSelector:(SEL)aSelector {
    NSAssert(self.tableViewDelegate != nil, @"self.tableViewDelegate should not be nil, assign your tableView.delegate before enabling gestureRecognizer", nil);
    if ([self.tableViewDelegate respondsToSelector:aSelector]) {
        return YES;
    }
    return [[self class] instancesRespondToSelector:aSelector];
}

#pragma mark Class method

+ (JTTableViewGestureRecognizer *)gestureRecognizerWithTableView:(UITableView *)tableView delegate:(id <JTTableViewGestureMoveRowDelegate>)delegate {
    JTTableViewGestureRecognizer *recognizer = [[JTTableViewGestureRecognizer alloc] init];
    recognizer.delegate             = delegate;
    recognizer.tableView            = tableView;
    recognizer.tableViewDelegate    = tableView.delegate;     // Assign the delegate before chaning the tableView's delegate
    tableView.delegate              = recognizer;
    
    UILongPressGestureRecognizer *longPress = [[UILongPressGestureRecognizer alloc] initWithTarget:recognizer action:@selector(longPressGestureRecognizer:)];
    [tableView addGestureRecognizer:longPress];
    longPress.delegate              = recognizer;
    recognizer.longPressRecognizer  = longPress;

    return recognizer;
}

@end


@implementation UITableView (JTTableViewGestureDelegate)

- (JTTableViewGestureRecognizer *)enableGestureTableViewWithDelegate:(id <JTTableViewGestureMoveRowDelegate>)delegate {
  return [JTTableViewGestureRecognizer gestureRecognizerWithTableView:self delegate:delegate];
}

#pragma mark Helper methods

- (void)reloadVisibleRowsExceptIndexPath:(NSIndexPath *)indexPath {
    NSMutableArray *visibleRows = [[self indexPathsForVisibleRows] mutableCopy];
    [visibleRows removeObject:indexPath];
    [self reloadRowsAtIndexPaths:visibleRows withRowAnimation:UITableViewRowAnimationNone];
}

@end
