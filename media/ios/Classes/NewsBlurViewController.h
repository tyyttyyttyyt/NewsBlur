//
//  NewsBlurViewController.h
//  NewsBlur
//
//  Created by Samuel Clay on 6/16/10.
//  Copyright NewsBlur 2010. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "NewsBlurAppDelegate.h"
#import "FolderTitleView.h"
#import "ASIHTTPRequest.h"
#import "PullToRefreshView.h"
#import "BaseViewController.h"
#import "WEPopoverController.h"

@class NewsBlurAppDelegate;

@interface NewsBlurViewController : BaseViewController 
<UITableViewDelegate, UITableViewDataSource,
UIAlertViewDelegate, PullToRefreshViewDelegate,
ASIHTTPRequestDelegate, NSCacheDelegate,
WEPopoverControllerDelegate,
UIPopoverControllerDelegate> {
    NewsBlurAppDelegate *appDelegate;
    
    NSMutableDictionary * activeFeedLocations;
    NSMutableDictionary *stillVisibleFeeds;
    NSMutableDictionary *visibleFolders;

    BOOL viewShowingAllFeeds;
    PullToRefreshView *pull;
    NSDate *lastUpdate;
    NSCache *imageCache;
    
    UIView *innerView;
	UITableView * feedTitlesTable;
	UIToolbar * feedViewToolbar;
    UISlider * feedScoreSlider;
    UIBarButtonItem * homeButton;
    UISegmentedControl * intelligenceControl;
    WEPopoverController *popoverController;
	Class popoverClass;
}

@property (nonatomic) IBOutlet NewsBlurAppDelegate *appDelegate;
@property (nonatomic) IBOutlet UIView *innerView;
@property (nonatomic) IBOutlet UITableView *feedTitlesTable;
@property (nonatomic) IBOutlet UIToolbar *feedViewToolbar;
@property (nonatomic) IBOutlet UISlider * feedScoreSlider;
@property (nonatomic) IBOutlet UIBarButtonItem * homeButton;
@property (nonatomic) NSMutableDictionary *activeFeedLocations;
@property (nonatomic) NSMutableDictionary *stillVisibleFeeds;
@property (nonatomic) NSMutableDictionary *visibleFolders;
@property (nonatomic, readwrite) BOOL viewShowingAllFeeds;
@property (nonatomic) PullToRefreshView *pull;
@property (nonatomic) NSDate *lastUpdate;
@property (nonatomic) NSCache *imageCache;
@property (nonatomic) IBOutlet UISegmentedControl * intelligenceControl;
@property (nonatomic, retain) WEPopoverController *popoverController;
@property (nonatomic) NSIndexPath *currentRowAtIndexPath;
@property (strong, nonatomic) IBOutlet UIView *noFocusMessage;
@property (strong, nonatomic) IBOutlet UIBarButtonItem *toolbarLeftMargin;

- (void)returnToApp;
- (void)fetchFeedList:(BOOL)showLoader;
- (void)finishedWithError:(ASIHTTPRequest *)request;
- (void)finishLoadingFeedList:(ASIHTTPRequest *)request;
- (void)finishRefreshingFeedList:(ASIHTTPRequest *)request;
- (void)setUserAvatarLayout:(UIInterfaceOrientation)orientation;
- (void)didSelectSectionHeader:(UIButton *)button;
- (IBAction)selectIntelligence;
- (void)didCollapseFolder:(UIButton *)button;
- (BOOL)isFeedVisible:(id)feedId;
- (void)changeToAllMode;
- (void)calculateFeedLocations;
- (IBAction)sectionTapped:(UIButton *)button;
- (IBAction)sectionUntapped:(UIButton *)button;
- (IBAction)sectionUntappedOutside:(UIButton *)button;
- (void)redrawUnreadCounts;
+ (int)computeMaxScoreForFeed:(NSDictionary *)feed;
- (void)loadFavicons;
- (void)loadAvatars;
- (void)saveAndDrawFavicons:(ASIHTTPRequest *)request;
- (void)requestFailed:(ASIHTTPRequest *)request;
- (void)refreshFeedList;
- (void)refreshFeedList:(id)feedId;
- (void)pullToRefreshViewShouldRefresh:(PullToRefreshView *)view;
- (void)showUserProfile;
- (void)showSettingsPopover:(id)sender;
- (NSDate *)pullToRefreshViewLastUpdated:(PullToRefreshView *)view;
- (void)fadeSelectedCell;
- (IBAction)tapAddSite:(id)sender;

- (void)resetToolbar;


@end
