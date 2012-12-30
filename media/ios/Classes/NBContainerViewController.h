//
//  NBContainerViewController.h
//  NewsBlur
//
//  Created by Roy Yang on 7/24/12.
//  Copyright (c) 2012 NewsBlur. All rights reserved.
//

#import <UIKit/UIKit.h>

@class NewsBlurAppDelegate;

@interface NBContainerViewController : UIViewController <UIPopoverControllerDelegate> {
    NewsBlurAppDelegate *appDelegate;
}

@property (readonly) BOOL storyTitlesOnLeft;
@property (readonly) int storyTitlesYCoordinate;
@property (atomic, strong) IBOutlet NewsBlurAppDelegate *appDelegate;


- (void)syncNextPreviousButtons;

- (void)adjustDashboardScreen;
- (void)adjustFeedDetailScreen;
- (void)adjustFeedDetailScreenForStoryTitles;

- (void)transitionToFeedDetail;
- (void)transitionFromFeedDetail;
- (void)transitionToShareView;
- (void)transitionFromShareView;

- (void)dragStoryToolbar:(int)yCoordinate;
- (void)showUserProfilePopover:(id)sender;
- (void)showFeedMenuPopover:(id)sender;
- (void)showFeedDetailMenuPopover:(id)sender;
- (void)showFontSettingsPopover:(id)sender;
- (void)showTrainingPopover:(id)sender;
- (void)showSitePopover:(id)sender;
- (void)hidePopover;
@end
