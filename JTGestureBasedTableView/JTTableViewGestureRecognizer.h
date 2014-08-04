/*
 * This file is part of the JTGestureBasedTableView package.
 * (c) James Tang <mystcolor@gmail.com>
 *
 * For the full copyright and license information, please view the LICENSE
 * file that was distributed with this source code.
 */

#import <UIKit/UIKit.h>

// JTTableViewRowAnimationDuration is decided to be as close as the internal settings of UITableViewRowAnimation duration
extern CGFloat const JTTableViewRowAnimationDuration;

@protocol JTTableViewGestureMoveRowDelegate;


@interface JTTableViewGestureRecognizer : NSObject <UITableViewDelegate>

@property (nonatomic, weak, readonly) UITableView *tableView;

+ (JTTableViewGestureRecognizer *)gestureRecognizerWithTableView:(UITableView *)tableView delegate:(id <JTTableViewGestureMoveRowDelegate>)delegate;

@end


// Conform to JTTableViewGestureMoveRowDelegate to enable features
// - long press to reorder cell
@protocol JTTableViewGestureMoveRowDelegate <NSObject>

- (BOOL)gestureRecognizer:(JTTableViewGestureRecognizer *)gestureRecognizer canMoveRowAtIndexPath:(NSIndexPath *)indexPath;
- (void)gestureRecognizer:(JTTableViewGestureRecognizer *)gestureRecognizer needsCreatePlaceholderForRowAtIndexPath:(NSIndexPath *)indexPath;
- (void)gestureRecognizer:(JTTableViewGestureRecognizer *)gestureRecognizer needsMoveRowAtIndexPath:(NSIndexPath *)sourceIndexPath toIndexPath:(NSIndexPath *)destinationIndexPath;
- (void)gestureRecognizer:(JTTableViewGestureRecognizer *)gestureRecognizer needsReplacePlaceholderForRowAtIndexPath:(NSIndexPath *)indexPath;

@optional
- (BOOL)gestureRecognizer:(JTTableViewGestureRecognizer *)gestureRecognizer canMoveRowAtIndexPath:(NSIndexPath *)sourceIndexPath toIndexPath:(NSIndexPath *)destinationIndexPath;

@end


@interface UITableView (JTTableViewGestureDelegate)

- (JTTableViewGestureRecognizer *)enableGestureTableViewWithDelegate:(id <JTTableViewGestureMoveRowDelegate>)delegate;

// Helper methods for updating cell after datasource changes
- (void)reloadVisibleRowsExceptIndexPath:(NSIndexPath *)indexPath;

@end
