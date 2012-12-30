//
//  FeedDetailViewController.m
//  NewsBlur
//
//  Created by Samuel Clay on 6/20/10.
//  Copyright 2010 NewsBlur. All rights reserved.
//

#import <QuartzCore/QuartzCore.h>
#import "FeedDetailViewController.h"
#import "NewsBlurAppDelegate.h"
#import "NBContainerViewController.h"
#import "FeedDetailTableCell.h"
#import "ASIFormDataRequest.h"
#import "UserProfileViewController.h"
#import "StoryDetailViewController.h"
#import "StoryPageControl.h"
#import "NSString+HTML.h"
#import "MBProgressHUD.h"
#import "Base64.h"
#import "JSON.h"
#import "StringHelper.h"
#import "Utilities.h"
#import "UIBarButtonItem+WEPopover.h"
#import "WEPopoverController.h"


#define kTableViewRowHeight 61;
#define kTableViewRiverRowHeight 81;
#define kTableViewShortRowDifference 15;
#define kMarkReadActionSheet 1;
#define kSettingsActionSheet 2;

@interface FeedDetailViewController ()

@property (nonatomic) UIActionSheet* actionSheet_;  // add this line

@end

@implementation FeedDetailViewController

@synthesize popoverController;
@synthesize storyTitlesTable, feedViewToolbar, feedScoreSlider, feedMarkReadButton;
@synthesize settingsButton;
@synthesize stories;
@synthesize appDelegate;
@synthesize feedPage;
@synthesize pageFetching;
@synthesize pageFinished;
@synthesize intelligenceControl;
@synthesize actionSheet_;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
	
    if ((self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil])) {
    }
    return self;
}
 
- (void)viewDidLoad {
    [super viewDidLoad];
    
    popoverClass = [WEPopoverController class];
    self.storyTitlesTable.backgroundColor = UIColorFromRGB(0xf4f4f4);
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    return YES;
}


- (void)willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation 
                                         duration:(NSTimeInterval)duration {
    [self setUserAvatarLayout:toInterfaceOrientation];
}

- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation {
    [self checkScroll];
}

- (void)viewWillAppear:(BOOL)animated {
    // 
    UIInterfaceOrientation orientation = [UIApplication sharedApplication].statusBarOrientation;
    [self setUserAvatarLayout:orientation];
    
    self.pageFinished = NO;
    [MBProgressHUD hideHUDForView:self.view animated:YES];
            
    // set center title
    UIView *titleLabel = [appDelegate makeFeedTitle:appDelegate.activeFeed];
    self.navigationItem.titleView = titleLabel;
    
    // set right avatar title image
    if (appDelegate.isSocialView) {
        UIButton *titleImageButton = [appDelegate makeRightFeedTitle:appDelegate.activeFeed];
        [titleImageButton addTarget:self action:@selector(showUserProfile) forControlEvents:UIControlEventTouchUpInside];
        UIBarButtonItem *titleImageBarButton = [[UIBarButtonItem alloc] 
                                                 initWithCustomView:titleImageButton];
        self.navigationItem.rightBarButtonItem = titleImageBarButton;
    } else {
        self.navigationItem.rightBarButtonItem = nil;
    }

    
    // Commenting out until training is ready...
    //    UIBarButtonItem *trainBarButton = [UIBarButtonItem alloc];
    //    [trainBarButton setImage:[UIImage imageNamed:@"train.png"]];
    //    [trainBarButton setEnabled:YES];
    //    [self.navigationItem setRightBarButtonItem:trainBarButton animated:YES];
    //    [trainBarButton release];
    
    NSMutableArray *indexPaths = [NSMutableArray array];
    for (id i in appDelegate.recentlyReadStories) {
        NSIndexPath *indexPath = [NSIndexPath indexPathForRow:[i intValue]
                                                inSection:0];
//        NSLog(@"Read story: %d", [i intValue]);
        [indexPaths addObject:indexPath];
    }
    if ([indexPaths count] > 0) {
        [self.storyTitlesTable beginUpdates];
        [self.storyTitlesTable reloadRowsAtIndexPaths:indexPaths withRowAnimation:UITableViewRowAnimationNone];
        [self.storyTitlesTable endUpdates];
        //[self.storyTitlesTable reloadData];
    }
    [appDelegate setRecentlyReadStories:[NSMutableArray array]];
    
	[super viewWillAppear:animated];
        
    if ((appDelegate.isSocialRiverView ||
         appDelegate.isSocialView ||
         (appDelegate.isRiverView &&
          [appDelegate.activeFolder isEqualToString:@"everything"]) ||
         [appDelegate.activeFolder isEqualToString:@"saved_stories"])) {
        settingsButton.enabled = NO;
    } else {
        settingsButton.enabled = YES;
    }
    
    if (appDelegate.isSocialRiverView || 
        (appDelegate.isRiverView &&
         [appDelegate.activeFolder isEqualToString:@"everything"]) ||
        [appDelegate.activeFolder isEqualToString:@"saved_stories"]) {
        feedMarkReadButton.enabled = NO;
    } else {
        feedMarkReadButton.enabled = YES;
    }
        
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone) {
        [self.storyTitlesTable reloadData];
        int location = appDelegate.locationOfActiveStory;
        NSIndexPath *indexPath = [NSIndexPath indexPathForRow:location inSection:0];
        if (indexPath) {
            [self.storyTitlesTable selectRowAtIndexPath:indexPath animated:NO scrollPosition:UITableViewScrollPositionNone];
        } 
        [self performSelector:@selector(fadeSelectedCell) withObject:self afterDelay:0.4];
    }
}

- (void)viewDidAppear:(BOOL)animated {
    if (appDelegate.inStoryDetail && UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone) {
        appDelegate.inStoryDetail = NO;
        [appDelegate.storyPageControl.currentPage clearStory];
        [appDelegate.storyPageControl.nextPage clearStory];
        [appDelegate.storyDetailViewController clearStory];
        [self checkScroll];
    }
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [self.popoverController dismissPopoverAnimated:YES];
    self.popoverController = nil;
}

- (void)viewDidDisappear:(BOOL)animated {
    
}

- (void)fadeSelectedCell {
    // have the selected cell deselect
    int location = appDelegate.locationOfActiveStory;
    
    NSIndexPath *indexPath = [NSIndexPath indexPathForRow:location inSection:0];
    if (indexPath) {
        [self.storyTitlesTable deselectRowAtIndexPath:indexPath animated:YES];
        
    }           

}

- (void)setUserAvatarLayout:(UIInterfaceOrientation)orientation {
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone) {
        if (UIInterfaceOrientationIsPortrait(orientation)) {
            UIButton *avatar = (UIButton *)self.navigationItem.rightBarButtonItem.customView; 
            CGRect buttonFrame = avatar.frame;
            buttonFrame.size = CGSizeMake(32, 32);
            avatar.frame = buttonFrame;
        } else {
            UIButton *avatar = (UIButton *)self.navigationItem.rightBarButtonItem.customView; 
            CGRect buttonFrame = avatar.frame;
            buttonFrame.size = CGSizeMake(28, 28);
            avatar.frame = buttonFrame;
        }
    }
}


#pragma mark -
#pragma mark Initialization

- (void)resetFeedDetail {
    self.pageFetching = NO;
    self.pageFinished = NO;
    self.feedPage = 1;
}

- (void)reloadPage {
    [self resetFeedDetail];

    [appDelegate setStories:nil];
    appDelegate.storyCount = 0;

    [self.storyTitlesTable reloadData];
    [storyTitlesTable scrollRectToVisible:CGRectMake(0, 0, 1, 1) animated:YES];

    
    if (appDelegate.isRiverView) {
        [self fetchRiverPage:1 withCallback:nil];
    } else {
        [self fetchFeedDetail:1 withCallback:nil];
    }
}

#pragma mark -
#pragma mark Regular and Social Feeds

- (void)fetchNextPage:(void(^)())callback {
    if (appDelegate.isRiverView) {
        [self fetchRiverPage:self.feedPage+1 withCallback:callback];
    } else {
        [self fetchFeedDetail:self.feedPage+1 withCallback:callback];
    }
}

- (void)fetchFeedDetail:(int)page withCallback:(void(^)())callback {
    NSString *theFeedDetailURL;
    NSUserDefaults *userPreferences = [NSUserDefaults standardUserDefaults];
    
    if (callback || (!self.pageFetching && !self.pageFinished)) {
    
        self.feedPage = page;
        self.pageFetching = YES;
        int storyCount = appDelegate.storyCount;
        if (storyCount == 0) {
            [self.storyTitlesTable reloadData];
            [storyTitlesTable scrollRectToVisible:CGRectMake(0, 0, 1, 1) animated:YES];
        }
        if (appDelegate.isSocialView) {
            theFeedDetailURL = [NSString stringWithFormat:@"http://%@/social/stories/%@/?page=%d", 
                                NEWSBLUR_URL,
                                [appDelegate.activeFeed objectForKey:@"user_id"],
                                self.feedPage];
        } else {
            theFeedDetailURL = [NSString stringWithFormat:@"http://%@/reader/feed/%@/?page=%d", 
                                NEWSBLUR_URL,
                                [appDelegate.activeFeed objectForKey:@"id"],
                                self.feedPage];
        }
        
        if ([userPreferences stringForKey:[appDelegate orderKey]]) {
            theFeedDetailURL = [NSString stringWithFormat:@"%@&order=%@",
                                theFeedDetailURL,
                                [userPreferences stringForKey:[appDelegate orderKey]]];
        }
        if ([userPreferences stringForKey:[appDelegate readFilterKey]]) {
            theFeedDetailURL = [NSString stringWithFormat:@"%@&read_filter=%@",
                                theFeedDetailURL,
                                [userPreferences stringForKey:[appDelegate readFilterKey]]];
        }
        
        [self cancelRequests];
        __weak ASIHTTPRequest *request = [self requestWithURL:theFeedDetailURL];
        [request setDelegate:self];
        [request setResponseEncoding:NSUTF8StringEncoding];
        [request setDefaultResponseEncoding:NSUTF8StringEncoding];
        [request setFailedBlock:^(void) {
            NSLog(@"in failed block %@", request);
            [self informError:[request error]];
        }];
        [request setCompletionBlock:^(void) {
            [self finishedLoadingFeed:request];
            if (callback) {
                callback();
            }
        }];
        [request setTimeOutSeconds:10];
        [request setTag:[[[appDelegate activeFeed] objectForKey:@"id"] intValue]];
        [request startAsynchronous];
    }
}

#pragma mark -
#pragma mark River of News

- (void)fetchRiverPage:(int)page withCallback:(void(^)())callback {
    NSUserDefaults *userPreferences = [NSUserDefaults standardUserDefaults];
    
    if (!self.pageFetching && !self.pageFinished) {
        self.feedPage = page;
        self.pageFetching = YES;
        int storyCount = appDelegate.storyCount;
        if (storyCount == 0) {
            [self.storyTitlesTable reloadData];
            [storyTitlesTable scrollRectToVisible:CGRectMake(0, 0, 1, 1) animated:YES];
        }
        
        NSString *theFeedDetailURL;
        
        if (appDelegate.isSocialRiverView) {
            theFeedDetailURL = [NSString stringWithFormat:
                                @"http://%@/social/river_stories/?page=%d", 
                                NEWSBLUR_URL,
                                self.feedPage];
        } else if (appDelegate.activeFolder == @"saved_stories") {
            theFeedDetailURL = [NSString stringWithFormat:
                                @"http://%@/reader/starred_stories/?page=%d",
                                NEWSBLUR_URL,
                                self.feedPage];
        } else {
            theFeedDetailURL = [NSString stringWithFormat:
                                @"http://%@/reader/river_stories/?feeds=%@&page=%d", 
                                NEWSBLUR_URL,
                                [appDelegate.activeFolderFeeds componentsJoinedByString:@"&feeds="],
                                self.feedPage];
        }
        
        
        if ([userPreferences stringForKey:[appDelegate orderKey]]) {
            theFeedDetailURL = [NSString stringWithFormat:@"%@&order=%@",
                                theFeedDetailURL,
                                [userPreferences stringForKey:[appDelegate orderKey]]];
        }
        if ([userPreferences stringForKey:[appDelegate readFilterKey]]) {
            theFeedDetailURL = [NSString stringWithFormat:@"%@&read_filter=%@",
                                theFeedDetailURL,
                                [userPreferences stringForKey:[appDelegate readFilterKey]]];
        }

        [self cancelRequests];
        __weak ASIHTTPRequest *request = [self requestWithURL:theFeedDetailURL];
        [request setDelegate:self];
        [request setResponseEncoding:NSUTF8StringEncoding];
        [request setDefaultResponseEncoding:NSUTF8StringEncoding];
        [request setFailedBlock:^(void) {
            [self informError:[request error]];
        }];
        [request setCompletionBlock:^(void) {
            [self finishedLoadingFeed:request];
            if (callback) {
                callback();
            }
        }];
        [request setTimeOutSeconds:30];
        [request startAsynchronous];
    }
}

#pragma mark -
#pragma mark Processing Stories

- (void)finishedLoadingFeed:(ASIHTTPRequest *)request {
    if ([request responseStatusCode] >= 500) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1.15 * NSEC_PER_SEC), 
                       dispatch_get_current_queue(), ^{
            [appDelegate.navigationController 
             popToViewController:[appDelegate.navigationController.viewControllers 
                                  objectAtIndex:0]  
             animated:YES];
        });
        [self informError:@"The server barfed!"];
        
        return;
    }
        
    NSString *responseString = [request responseString];
    NSData *responseData = [responseString dataUsingEncoding:NSUTF8StringEncoding];    
    NSError *error;
    NSDictionary *results = [NSJSONSerialization 
                             JSONObjectWithData:responseData
                             options:kNilOptions 
                             error:&error];
        
    if (!(appDelegate.isRiverView || appDelegate.isSocialView || appDelegate.isSocialRiverView) 
        && request.tag != [[results objectForKey:@"feed_id"] intValue]) {
        return;
    }
    
    if (appDelegate.isSocialView || appDelegate.isSocialRiverView) {
        NSArray *newFeeds = [results objectForKey:@"feeds"];
        for (int i = 0; i < newFeeds.count; i++){
            NSString *feedKey = [NSString stringWithFormat:@"%@", [[newFeeds objectAtIndex:i] objectForKey:@"id"]];
            [appDelegate.dictActiveFeeds setObject:[newFeeds objectAtIndex:i] 
                      forKey:feedKey];
        }
        [self loadFaviconsFromActiveFeed];
    }
        
    NSArray *newStories = [results objectForKey:@"stories"];
    NSMutableArray *confirmedNewStories = [[NSMutableArray alloc] init];
    if ([appDelegate.activeFeedStories count]) {
        NSMutableSet *storyIds = [NSMutableSet set];
        for (id story in appDelegate.activeFeedStories) {
            [storyIds addObject:[story objectForKey:@"id"]];
        }
        for (id story in newStories) {
            if (![storyIds containsObject:[story objectForKey:@"id"]]) {
                [confirmedNewStories addObject:story];
            }
        }
    } else {
        confirmedNewStories = [newStories copy];
    }
    
    // Adding new user profiles to appDelegate.activeFeedUserProfiles

    NSArray *newUserProfiles = [[NSArray alloc] init];
    if ([results objectForKey:@"user_profiles"] != nil) {
        newUserProfiles = [results objectForKey:@"user_profiles"];
    }
    // add self to user profiles
    if (self.feedPage == 1) {
        newUserProfiles = [newUserProfiles arrayByAddingObject:appDelegate.dictUserProfile];
    }
    
    if ([newUserProfiles count]){
        NSMutableArray *confirmedNewUserProfiles = [NSMutableArray array];
        if ([appDelegate.activeFeedUserProfiles count]) {
            NSMutableSet *userProfileIds = [NSMutableSet set];
            for (id userProfile in appDelegate.activeFeedUserProfiles) {
                [userProfileIds addObject:[userProfile objectForKey:@"id"]];
            }
            for (id userProfile in newUserProfiles) {
                if (![userProfileIds containsObject:[userProfile objectForKey:@"id"]]) {
                    [confirmedNewUserProfiles addObject:userProfile];
                }
            }
        } else {
            confirmedNewUserProfiles = [newUserProfiles copy];
        }
        
        
        if (self.feedPage == 1) {
            [appDelegate setFeedUserProfiles:confirmedNewUserProfiles];
        } else if (newUserProfiles.count > 0) {        
            [appDelegate addFeedUserProfiles:confirmedNewUserProfiles];
        }
        
//        NSLog(@"activeFeedUserProfiles is %@", appDelegate.activeFeedUserProfiles);
//        NSLog(@"# of user profiles added: %i", appDelegate.activeFeedUserProfiles.count);
//        NSLog(@"user profiles added: %@", appDelegate.activeFeedUserProfiles);
    }
    
    [self renderStories:confirmedNewStories];
    [appDelegate.storyPageControl resizeScrollView];
}

#pragma mark - 
#pragma mark Stories

- (void)renderStories:(NSArray *)newStories {
    NSInteger existingStoriesCount = [[appDelegate activeFeedStoryLocations] count];
    NSInteger newStoriesCount = [newStories count];
    
    if (self.feedPage == 1) {
        [appDelegate setStories:newStories];
    } else if (newStoriesCount > 0) {        
        [appDelegate addStories:newStories];
    }
    
    NSInteger newVisibleStoriesCount = [[appDelegate activeFeedStoryLocations] count] - existingStoriesCount;
    
    if (existingStoriesCount > 0 && newVisibleStoriesCount > 0) {
        NSMutableArray *indexPaths = [[NSMutableArray alloc] init];
        for (int i=0; i < newVisibleStoriesCount; i++) {
            [indexPaths addObject:[NSIndexPath indexPathForRow:(existingStoriesCount+i) 
                                                     inSection:0]];
        }
        
        [self.storyTitlesTable reloadData];

    } else if (newVisibleStoriesCount > 0) {
        [self.storyTitlesTable reloadData];
        
    } else if (newStoriesCount == 0 || 
               (self.feedPage > 25 &&
                existingStoriesCount >= [appDelegate unreadCount])) {
        self.pageFinished = YES;
        [self.storyTitlesTable reloadData];
    }
        
    self.pageFetching = NO;
    
    // test for tryfeed
    if (appDelegate.inFindingStoryMode && appDelegate.tryFeedStoryId) {
        for (int i = 0; i < appDelegate.activeFeedStories.count; i++) {
            NSString *storyIdStr = [[appDelegate.activeFeedStories objectAtIndex:i] objectForKey:@"id"];
            if ([storyIdStr isEqualToString:appDelegate.tryFeedStoryId]) {
                NSDictionary *feed = [appDelegate.activeFeedStories objectAtIndex:i];
                
                int score = [NewsBlurAppDelegate computeStoryScore:[feed objectForKey:@"intelligence"]];
                
                if (score < appDelegate.selectedIntelligence) {
                    [self changeIntelligence:score];
                }
                int locationOfStoryId = [appDelegate locationOfStoryId:storyIdStr];
                NSIndexPath *indexPath = [NSIndexPath indexPathForRow:locationOfStoryId inSection:0];

                [self.storyTitlesTable selectRowAtIndexPath:indexPath animated:YES scrollPosition:UITableViewScrollPositionBottom];
                
                FeedDetailTableCell *cell = (FeedDetailTableCell *)[self.storyTitlesTable cellForRowAtIndexPath:indexPath];
                [self loadStory:cell atRow:indexPath.row];
                
                // found the story, reset the two flags.
                appDelegate.tryFeedStoryId = nil;
                appDelegate.inFindingStoryMode = NO;
            }
        }
    }
    
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        [appDelegate.masterContainerViewController syncNextPreviousButtons];
    }
    
    [self performSelector:@selector(checkScroll)
               withObject:nil
               afterDelay:0.2];
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
    
    // inform the user
    NSLog(@"Connection failed! Error - %@",
          [error localizedDescription]);
    
    self.pageFetching = NO;
    
	// User clicking on another link before the page loads is OK.
	if ([error code] != NSURLErrorCancelled) {
		[self informError:error];
	}
}

- (UITableViewCell *)makeLoadingCell {
    UITableViewCell *cell = [[UITableViewCell alloc] 
                              initWithStyle:UITableViewCellStyleSubtitle 
                              reuseIdentifier:@"NoReuse"];
    
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    if (self.pageFinished) {
        UIImage *img = [UIImage imageNamed:@"fleuron.png"];
        UIImageView *fleuron = [[UIImageView alloc] initWithImage:img];
        int height = 0;
        
        if (appDelegate.isRiverView || appDelegate.isSocialView) {
            height = kTableViewRiverRowHeight;
        } else {
            height = kTableViewRowHeight;
        }
        
        UIInterfaceOrientation orientation = [UIApplication sharedApplication].statusBarOrientation;
        if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad
            && !appDelegate.masterContainerViewController.storyTitlesOnLeft
            && UIInterfaceOrientationIsPortrait(orientation)) {
            height = height - kTableViewShortRowDifference;
        }

        fleuron.frame = CGRectMake(0, 0, self.view.frame.size.width, height);
        fleuron.contentMode = UIViewContentModeCenter;
        [cell.contentView addSubview:fleuron];
    } else {
        cell.textLabel.text = @"Loading...";
        
        UIActivityIndicatorView *spinner = [[UIActivityIndicatorView alloc] 
                                             initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
        UIImage *spacer = [UIImage imageNamed:@"spacer"];
        UIGraphicsBeginImageContext(spinner.frame.size);        
        [spacer drawInRect:CGRectMake(0,0,spinner.frame.size.width,spinner.frame.size.height)];
        UIImage* resizedSpacer = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
        cell.imageView.image = resizedSpacer;
        [cell.imageView addSubview:spinner];
        [spinner startAnimating];
    }
    
    return cell;
}

#pragma mark -
#pragma mark Table View - Feed List

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section { 
    int storyCount = [[appDelegate activeFeedStoryLocations] count];

    // The +1 is for the finished/loading bar.
    return storyCount + 1;
}

- (UITableViewCell *)tableView:(UITableView *)tableView 
         cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    NSString *cellIdentifier;
    NSDictionary *feed ;
    
    if (appDelegate.isRiverView || appDelegate.isSocialView) {
        cellIdentifier = @"FeedRiverDetailCellIdentifier";
    } else {
        cellIdentifier = @"FeedDetailCellIdentifier";
    }
    
    FeedDetailTableCell *cell = (FeedDetailTableCell *)[tableView 
                                                        dequeueReusableCellWithIdentifier:cellIdentifier]; 
    if (cell == nil) {
        cell = [[FeedDetailTableCell alloc] initWithStyle:UITableViewCellStyleDefault
                                          reuseIdentifier:nil];
    }
        
    if (indexPath.row >= [[appDelegate activeFeedStoryLocations] count]) {
        return [self makeLoadingCell];
    }
        
    NSDictionary *story = [self getStoryAtRow:indexPath.row];
    
    id feedId = [story objectForKey:@"story_feed_id"];
    NSString *feedIdStr = [NSString stringWithFormat:@"%@", feedId];
    
    if (appDelegate.isSocialView || appDelegate.isSocialRiverView) {
        feed = [appDelegate.dictActiveFeeds objectForKey:feedIdStr];
        // this is to catch when a user is already subscribed
        if (!feed) {
            feed = [appDelegate.dictFeeds objectForKey:feedIdStr];
        }
    } else {
        feed = [appDelegate.dictFeeds objectForKey:feedIdStr];
    }
        
    NSString *siteTitle = [feed objectForKey:@"feed_title"];
    cell.siteTitle = siteTitle; 

    NSString *title = [story objectForKey:@"story_title"];
    cell.storyTitle = [title stringByDecodingHTMLEntities];

    cell.storyDate = [story objectForKey:@"short_parsed_date"];
    
    if ([[story objectForKey:@"story_authors"] class] != [NSNull class]) {
        cell.storyAuthor = [[story objectForKey:@"story_authors"] uppercaseString];
    } else {
        cell.storyAuthor = @"";
    }
    
    // feed color bar border
    unsigned int colorBorder = 0;
    NSString *faviconColor = [feed valueForKey:@"favicon_color"];

    if ([faviconColor class] == [NSNull class]) {
        faviconColor = @"505050";
    }    
    NSScanner *scannerBorder = [NSScanner scannerWithString:faviconColor];
    [scannerBorder scanHexInt:&colorBorder];

    cell.feedColorBar = UIColorFromRGB(colorBorder);
    
    // feed color bar border
    NSString *faviconFade = [feed valueForKey:@"favicon_border"];
    if ([faviconFade class] == [NSNull class]) {
        faviconFade = @"505050";
    }    
    scannerBorder = [NSScanner scannerWithString:faviconFade];
    [scannerBorder scanHexInt:&colorBorder];
    cell.feedColorBarTopBorder =  UIColorFromRGB(colorBorder);
    
    // favicon
    cell.siteFavicon = [Utilities getImage:feedIdStr];
    
    // undread indicator
    
    int score = [NewsBlurAppDelegate computeStoryScore:[story objectForKey:@"intelligence"]];
    cell.storyScore = score;
    
    cell.isRead = [[story objectForKey:@"read_status"] intValue] == 1;
    
    UIInterfaceOrientation orientation = [UIApplication sharedApplication].statusBarOrientation;
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad
        && !appDelegate.masterContainerViewController.storyTitlesOnLeft
        && UIInterfaceOrientationIsPortrait(orientation)) {
        cell.isShort = YES;
    }

    if (appDelegate.isRiverView || appDelegate.isSocialView || appDelegate.isSocialRiverView) {
        cell.isRiverOrSocial = YES;
    }

    if (UI_USER_INTERFACE_IDIOM() ==  UIUserInterfaceIdiomPad) {
        int rowIndex = [appDelegate locationOfActiveStory];
        if (rowIndex == indexPath.row) {
            [self.storyTitlesTable selectRowAtIndexPath:indexPath animated:NO scrollPosition:UITableViewScrollPositionNone];
        } 
    }

	return cell;
}

- (void)loadStory:(FeedDetailTableCell *)cell atRow:(int)row {
    cell.isRead = YES;
    [cell setNeedsLayout];
    int storyIndex = [appDelegate indexFromLocation:row];
    appDelegate.activeStory = [[appDelegate activeFeedStories] objectAtIndex:storyIndex];
    [appDelegate setOriginalStoryCount:[appDelegate unreadCount]];
    [appDelegate loadStoryDetailView];
}

- (void)redrawUnreadStory {
    int rowIndex = [appDelegate locationOfActiveStory];
    NSIndexPath *indexPath = [NSIndexPath indexPathForRow:rowIndex inSection:0];
    FeedDetailTableCell *cell = (FeedDetailTableCell*) [self.storyTitlesTable cellForRowAtIndexPath:indexPath];
    cell.isRead = [[appDelegate.activeStory objectForKey:@"read_status"] boolValue];
    [cell setNeedsDisplay];
}

- (void)changeActiveStoryTitleCellLayout {
    int rowIndex = [appDelegate locationOfActiveStory];
    NSIndexPath *indexPath = [NSIndexPath indexPathForRow:rowIndex inSection:0];
    FeedDetailTableCell *cell = (FeedDetailTableCell*) [self.storyTitlesTable cellForRowAtIndexPath:indexPath];
    cell.isRead = YES;
    [cell setNeedsLayout];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.row < [appDelegate.activeFeedStoryLocations count]) {
        // mark the cell as read
        FeedDetailTableCell *cell = (FeedDetailTableCell*) [tableView cellForRowAtIndexPath:indexPath];        
        [self loadStory:cell atRow:indexPath.row];
    }
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (appDelegate.isRiverView || appDelegate.isSocialView || appDelegate.isSocialRiverView) {
        int height = kTableViewRiverRowHeight;
        UIInterfaceOrientation orientation = [UIApplication sharedApplication].statusBarOrientation;
        if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad
            && !appDelegate.masterContainerViewController.storyTitlesOnLeft
            && UIInterfaceOrientationIsPortrait(orientation)) {
            height = height - kTableViewShortRowDifference;
        }
        return height;
    } else {
        int height = kTableViewRowHeight;
        UIInterfaceOrientation orientation = [UIApplication sharedApplication].statusBarOrientation;
        if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad
            && !appDelegate.masterContainerViewController.storyTitlesOnLeft
            && UIInterfaceOrientationIsPortrait(orientation)) {
            height = height - kTableViewShortRowDifference;
        }
        return height;
    }
}

- (void)scrollViewDidScroll: (UIScrollView *)scroll {
    [self checkScroll];
}

- (void)checkScroll {
    NSInteger currentOffset = self.storyTitlesTable.contentOffset.y;
    NSInteger maximumOffset = self.storyTitlesTable.contentSize.height - self.storyTitlesTable.frame.size.height;
    
    if (maximumOffset - currentOffset <= 60.0 || 
        (appDelegate.inFindingStoryMode)) {
        if (appDelegate.isRiverView) {
            [self fetchRiverPage:self.feedPage+1 withCallback:nil];
        } else {
            [self fetchFeedDetail:self.feedPage+1 withCallback:nil];   
        }
    }
}

- (IBAction)selectIntelligence {
    NSInteger newLevel = [self.intelligenceControl selectedSegmentIndex] - 1;
    [self changeIntelligence:newLevel];
    
    [self performSelector:@selector(checkScroll)
                withObject:nil
                afterDelay:1.0];
}

- (void)changeIntelligence:(NSInteger)newLevel {
    NSInteger previousLevel = [appDelegate selectedIntelligence];
    NSMutableArray *insertIndexPaths = [NSMutableArray array];
    NSMutableArray *deleteIndexPaths = [NSMutableArray array];
    
    if (newLevel == previousLevel) return;
    
    if (newLevel < previousLevel) {
        [appDelegate setSelectedIntelligence:newLevel];
        NSUserDefaults *userPreferences = [NSUserDefaults standardUserDefaults];   
        [userPreferences setInteger:(newLevel + 1) forKey:@"selectedIntelligence"];
        [userPreferences synchronize];
        
        [appDelegate calculateStoryLocations];
    }
    
    for (int i=0; i < [[appDelegate activeFeedStoryLocations] count]; i++) {
        int location = [[[appDelegate activeFeedStoryLocations] objectAtIndex:i] intValue];
        NSIndexPath *indexPath = [NSIndexPath indexPathForRow:i inSection:0];
        NSDictionary *story = [appDelegate.activeFeedStories objectAtIndex:location];
        int score = [NewsBlurAppDelegate computeStoryScore:[story objectForKey:@"intelligence"]];
        
        if (previousLevel == -1) {
            if (newLevel == 0 && score == -1) {
                [deleteIndexPaths addObject:indexPath];
            } else if (newLevel == 1 && score < 1) {
                [deleteIndexPaths addObject:indexPath];
            }
        } else if (previousLevel == 0) {
            if (newLevel == -1 && score == -1) {
                [insertIndexPaths addObject:indexPath];
            } else if (newLevel == 1 && score == 0) {
                [deleteIndexPaths addObject:indexPath];
            }
        } else if (previousLevel == 1) {
            if (newLevel == 0 && score == 0) {
                [insertIndexPaths addObject:indexPath];
            } else if (newLevel == -1 && score < 1) {
                [insertIndexPaths addObject:indexPath];
            }
        }
    }
    
    if (newLevel > previousLevel) {
        [appDelegate setSelectedIntelligence:newLevel];
        [appDelegate calculateStoryLocations];
    }
    
    [self.storyTitlesTable beginUpdates];
    if ([deleteIndexPaths count] > 0) {
        [self.storyTitlesTable deleteRowsAtIndexPaths:deleteIndexPaths 
                                     withRowAnimation:UITableViewRowAnimationNone];
    }
    if ([insertIndexPaths count] > 0) {
        [self.storyTitlesTable insertRowsAtIndexPaths:insertIndexPaths 
                                     withRowAnimation:UITableViewRowAnimationNone];
    }
    [self.storyTitlesTable endUpdates];
}

- (NSDictionary *)getStoryAtRow:(NSInteger)indexPathRow {
    int row = [[[appDelegate activeFeedStoryLocations] objectAtIndex:indexPathRow] intValue];
    return [appDelegate.activeFeedStories objectAtIndex:row];
}

#pragma mark -
#pragma mark Feed Actions


- (void)markFeedsReadWithAllStories:(BOOL)includeHidden {
    NSLog(@"mark feeds read: %d %d", appDelegate.isRiverView, includeHidden);
    if (appDelegate.isRiverView && includeHidden) {
        // Mark folder as read
        NSString *urlString = [NSString stringWithFormat:@"http://%@/reader/mark_feed_as_read",
                               NEWSBLUR_URL];
        NSURL *url = [NSURL URLWithString:urlString];
        ASIFormDataRequest *request = [ASIFormDataRequest requestWithURL:url];
        for (id feed_id in [appDelegate.dictFolders objectForKey:appDelegate.activeFolder]) {
            [request addPostValue:feed_id forKey:@"feed_id"];
        }
        [request setDelegate:nil];
        [request startAsynchronous];
        
        [appDelegate markActiveFolderAllRead];
    } else if (!appDelegate.isRiverView && includeHidden) {
        // Mark feed as read
        NSString *urlString = [NSString stringWithFormat:@"http://%@/reader/mark_feed_as_read",
                               NEWSBLUR_URL];
        NSURL *url = [NSURL URLWithString:urlString];
        ASIFormDataRequest *request = [ASIFormDataRequest requestWithURL:url];
        [request setPostValue:[appDelegate.activeFeed objectForKey:@"id"] forKey:@"feed_id"];
        [request setDidFinishSelector:@selector(finishMarkAllAsRead:)];
        [request setDidFailSelector:@selector(requestFailed:)];
        [request setDelegate:self];
        [request startAsynchronous];
        [appDelegate markFeedAllRead:[appDelegate.activeFeed objectForKey:@"id"]];
    } else {
        // Mark visible stories as read
        NSDictionary *feedsStories = [appDelegate markVisibleStoriesRead];
        NSString *urlString = [NSString stringWithFormat:@"http://%@/reader/mark_feed_stories_as_read",
                               NEWSBLUR_URL];
        NSURL *url = [NSURL URLWithString:urlString];
        ASIFormDataRequest *request = [ASIFormDataRequest requestWithURL:url];
        [request setPostValue:[feedsStories JSONRepresentation] forKey:@"feeds_stories"]; 
        [request setDelegate:self];
        [request setDidFinishSelector:@selector(finishMarkAllAsRead:)];
        [request setDidFailSelector:@selector(requestFailed:)];
        [request startAsynchronous];
    }
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        [appDelegate.navigationController popToRootViewControllerAnimated:YES];
        [appDelegate.masterContainerViewController transitionFromFeedDetail];
    } else {
        [appDelegate.navigationController 
         popToViewController:[appDelegate.navigationController.viewControllers 
                              objectAtIndex:0]  
         animated:YES];
    }
}

- (void)finishMarkAllAsRead:(ASIHTTPRequest *)request {
//    NSString *responseString = [request responseString];
//    NSData *responseData = [responseString dataUsingEncoding:NSUTF8StringEncoding];    
//    NSError *error;
//    NSDictionary *results = [NSJSONSerialization 
//                             JSONObjectWithData:responseData
//                             options:kNilOptions 
//                             error:&error];
    

}

- (IBAction)doOpenMarkReadActionSheet:(id)sender {
    // already displaying action sheet?
    if (self.actionSheet_) {
        [self.actionSheet_ dismissWithClickedButtonIndex:-1 animated:YES];
        self.actionSheet_ = nil;
        return;
    }
    
    // Individual sites just get marked as read, no action sheet needed.
    if (!appDelegate.isRiverView) {
        [self markFeedsReadWithAllStories:YES];
        return;
    }
    
    NSString *title = appDelegate.isRiverView ? 
                      appDelegate.activeFolder : 
                      [appDelegate.activeFeed objectForKey:@"feed_title"];
    UIActionSheet *options = [[UIActionSheet alloc] 
                              initWithTitle:title
                              delegate:self
                              cancelButtonTitle:nil
                              destructiveButtonTitle:nil
                              otherButtonTitles:nil];
    
    self.actionSheet_ = options;
    
    int visibleUnreadCount = appDelegate.visibleUnreadCount;
    int totalUnreadCount = [appDelegate unreadCount];
    NSArray *buttonTitles = nil;
    BOOL showVisible = YES;
    BOOL showEntire = YES;
    if ([appDelegate.activeFolder isEqualToString:@"everything"]) showEntire = NO;
    if (visibleUnreadCount >= totalUnreadCount || visibleUnreadCount <= 0) showVisible = NO;
    NSString *entireText = [NSString stringWithFormat:@"Mark %@ read", 
                            appDelegate.isRiverView ? 
                            @"entire folder" : 
                            @"this site"];
    NSString *visibleText = [NSString stringWithFormat:@"Mark %@ read", 
                             visibleUnreadCount == 1 ? @"this story as" : 
                                [NSString stringWithFormat:@"these %d stories", 
                                 visibleUnreadCount]];
    if (showVisible && showEntire) {
        buttonTitles = [NSArray arrayWithObjects:visibleText, entireText, nil];
        options.destructiveButtonIndex = 1;
    } else if (showVisible && !showEntire) {
        buttonTitles = [NSArray arrayWithObjects:visibleText, nil];
        options.destructiveButtonIndex = -1;
    } else if (!showVisible && showEntire) {
        buttonTitles = [NSArray arrayWithObjects:entireText, nil];
        options.destructiveButtonIndex = 0;
    }
    
    for (id title in buttonTitles) {
        [options addButtonWithTitle:title];
    }
    options.cancelButtonIndex = [options addButtonWithTitle:@"Cancel"];
    
    options.tag = kMarkReadActionSheet;
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        [options showFromBarButtonItem:self.feedMarkReadButton animated:YES];
    } else {
        [options showInView:self.view];
    }
}

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex {
//    NSLog(@"Action option #%d on %d", buttonIndex, actionSheet.tag);
    if (actionSheet.tag == 1) {
        int visibleUnreadCount = appDelegate.visibleUnreadCount;
        int totalUnreadCount = [appDelegate unreadCount];
        BOOL showVisible = YES;
        BOOL showEntire = YES;
        if ([appDelegate.activeFolder isEqualToString:@"everything"]) showEntire = NO;
        if (visibleUnreadCount >= totalUnreadCount || visibleUnreadCount <= 0) showVisible = NO;
//        NSLog(@"Counts: %d %d = %d", visibleUnreadCount, totalUnreadCount, visibleUnreadCount >= totalUnreadCount || visibleUnreadCount <= 0);

        if (showVisible && showEntire) {
            if (buttonIndex == 0) {
                [self markFeedsReadWithAllStories:NO];
            } else if (buttonIndex == 1) {
                [self markFeedsReadWithAllStories:YES];
            }               
        } else if (showVisible && !showEntire) {
            if (buttonIndex == 0) {
                [self markFeedsReadWithAllStories:NO];
            }   
        } else if (!showVisible && showEntire) {
            if (buttonIndex == 0) {
                [self markFeedsReadWithAllStories:YES];
            }
        }
    } else if (actionSheet.tag == 2) {
        if (buttonIndex == 0) {
            [self confirmDeleteSite];
        } else if (buttonIndex == 1) {
            [self openMoveView];
        } else if (buttonIndex == 2) {
            [self instafetchFeed];
        }
    } 
}

- (void)actionSheet:(UIActionSheet *)actionSheet didDismissWithButtonIndex:(NSInteger)buttonIndex {
    // just set to nil
    actionSheet_ = nil;
}

- (IBAction)doOpenSettingsActionSheet:(id)sender {
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        [appDelegate.masterContainerViewController showFeedDetailMenuPopover:sender];
    } else {
        if (self.popoverController == nil) {
            self.popoverController = [[WEPopoverController alloc]
                                      initWithContentViewController:(UIViewController *)appDelegate.feedDetailMenuViewController];
            self.popoverController.delegate = self;
        } else {
            [self.popoverController dismissPopoverAnimated:YES];
            self.popoverController = nil;
        }
        
        if ([self.popoverController respondsToSelector:@selector(setContainerViewProperties:)]) {
            [self.popoverController setContainerViewProperties:[self improvedContainerViewProperties]];
        }
        [self.popoverController setPopoverContentSize:CGSizeMake(260, appDelegate.isRiverView ? 38 * 3 : 38 * 5)];
        [self.popoverController presentPopoverFromBarButtonItem:self.settingsButton
                                       permittedArrowDirections:UIPopoverArrowDirectionDown
                                                       animated:YES];
    }

}

- (void)confirmDeleteSite {
    UIAlertView *deleteConfirm = [[UIAlertView alloc] 
                                  initWithTitle:@"Positive?" 
                                  message:nil 
                                  delegate:self 
                                  cancelButtonTitle:@"Cancel" 
                                  otherButtonTitles:@"Delete", 
                                  nil];
    [deleteConfirm show];
    [deleteConfirm setTag:0];
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
    if (alertView.tag == 0) {
        if (buttonIndex == 0) {
            return;
        } else {
            if (appDelegate.isRiverView) {
                [self deleteFolder];
            } else {
                [self deleteSite];
            }
        }
    }
}

- (void)deleteSite {
    [MBProgressHUD hideHUDForView:self.view animated:YES];
    MBProgressHUD *HUD = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
    HUD.labelText = @"Deleting...";
    
    NSString *theFeedDetailURL = [NSString stringWithFormat:@"http://%@/reader/delete_feed", 
                                  NEWSBLUR_URL];
    NSURL *urlFeedDetail = [NSURL URLWithString:theFeedDetailURL];
    
    __weak ASIFormDataRequest *request = [ASIFormDataRequest requestWithURL:urlFeedDetail];
    [request setDelegate:self];
    [request addPostValue:[[appDelegate activeFeed] objectForKey:@"id"] forKey:@"feed_id"];
    [request addPostValue:[appDelegate extractFolderName:appDelegate.activeFolder] forKey:@"in_folder"];
    [request setFailedBlock:^(void) {
        [self informError:[request error]];
    }];
    [request setCompletionBlock:^(void) {
        [appDelegate reloadFeedsView:YES];
        [appDelegate.navigationController 
         popToViewController:[appDelegate.navigationController.viewControllers 
                              objectAtIndex:0]  
         animated:YES];
        [MBProgressHUD hideHUDForView:self.view animated:YES];
    }];
    [request setTimeOutSeconds:30];
    [request setTag:[[[appDelegate activeFeed] objectForKey:@"id"] intValue]];
    [request startAsynchronous];
}

- (void)deleteFolder {
    [MBProgressHUD hideHUDForView:self.view animated:YES];
    MBProgressHUD *HUD = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
    HUD.labelText = @"Deleting...";
    
    NSString *theFeedDetailURL = [NSString stringWithFormat:@"http://%@/reader/delete_folder", 
                                  NEWSBLUR_URL];
    NSURL *urlFeedDetail = [NSURL URLWithString:theFeedDetailURL];
    
    __weak ASIFormDataRequest *request = [ASIFormDataRequest requestWithURL:urlFeedDetail];
    [request setDelegate:self];
    [request addPostValue:[appDelegate extractFolderName:appDelegate.activeFolder] 
                   forKey:@"folder_to_delete"];
    [request addPostValue:[appDelegate extractFolderName:[appDelegate extractParentFolderName:appDelegate.activeFolder]] 
                   forKey:@"in_folder"];
    [request setFailedBlock:^(void) {
        [self informError:[request error]];
    }];
    [request setCompletionBlock:^(void) {
        [appDelegate reloadFeedsView:YES];
        [appDelegate.navigationController 
         popToViewController:[appDelegate.navigationController.viewControllers 
                              objectAtIndex:0]  
         animated:YES];
        [MBProgressHUD hideHUDForView:self.view animated:YES];
    }];
    [request setTimeOutSeconds:30];
    [request startAsynchronous];
}

- (void)openMoveView {
    [appDelegate showMoveSite];
}

- (void)showUserProfile {
    appDelegate.activeUserProfileId = [NSString stringWithFormat:@"%@", [appDelegate.activeFeed objectForKey:@"user_id"]];
    appDelegate.activeUserProfileName = [NSString stringWithFormat:@"%@", [appDelegate.activeFeed objectForKey:@"username"]];
    [appDelegate showUserProfileModal:self.navigationItem.rightBarButtonItem];
}

- (void)changeActiveFeedDetailRow {
    int rowIndex = [appDelegate locationOfActiveStory];
                    
    NSIndexPath *indexPath = [NSIndexPath indexPathForRow:rowIndex inSection:0];
    NSIndexPath *offsetIndexPath = [NSIndexPath indexPathForRow:rowIndex - 1 inSection:0];

    [storyTitlesTable selectRowAtIndexPath:indexPath 
                                  animated:YES 
                            scrollPosition:UITableViewScrollPositionNone];
    
    // check to see if the cell is completely visible
    CGRect cellRect = [storyTitlesTable rectForRowAtIndexPath:indexPath];
    
    cellRect = [storyTitlesTable convertRect:cellRect toView:storyTitlesTable.superview];
    
    BOOL completelyVisible = CGRectContainsRect(storyTitlesTable.frame, cellRect);
    
    if (!completelyVisible) {
        [storyTitlesTable scrollToRowAtIndexPath:offsetIndexPath 
                                atScrollPosition:UITableViewScrollPositionTop 
                                        animated:YES];
    }
}


#pragma mark -
#pragma mark instafetchFeed

// called when the user taps refresh button

- (void)instafetchFeed {
    NSLog(@"Instafetch");
    
    NSString *urlString = [NSString 
                           stringWithFormat:@"http://%@/reader/refresh_feed/%@", 
                           NEWSBLUR_URL,
                           [appDelegate.activeFeed objectForKey:@"id"]];
    [self cancelRequests];
    __block ASIHTTPRequest *request = [self requestWithURL:urlString];
    [request setDelegate:self];
    [request setResponseEncoding:NSUTF8StringEncoding];
    [request setDefaultResponseEncoding:NSUTF8StringEncoding];
    [request setDidFinishSelector:@selector(finishedRefreshingFeed:)];
    [request setDidFailSelector:@selector(failRefreshingFeed:)];
    [request setTimeOutSeconds:60];
    [request startAsynchronous];
    
    [appDelegate setStories:nil];
    self.feedPage = 1;
    self.pageFetching = YES;
    [self.storyTitlesTable reloadData];
    [storyTitlesTable scrollRectToVisible:CGRectMake(0, 0, 1, 1) animated:YES];
}

- (void)finishedRefreshingFeed:(ASIHTTPRequest *)request {
    NSString *responseString = [request responseString];
    NSData *responseData = [responseString dataUsingEncoding:NSUTF8StringEncoding];    
    NSError *error;
    NSDictionary *results = [NSJSONSerialization 
                             JSONObjectWithData:responseData
                             options:kNilOptions 
                             error:&error];
    
    [self renderStories:[results objectForKey:@"stories"]];    
}

- (void)failRefreshingFeed:(ASIHTTPRequest *)request {
    NSLog(@"Fail: %@", request);
    [self informError:[request error]];
    [self fetchFeedDetail:1 withCallback:nil];
}

#pragma mark -
#pragma mark loadSocial Feeds

- (void)loadFaviconsFromActiveFeed {
    NSArray * keys = [appDelegate.dictActiveFeeds allKeys];
    
    if (![keys count]) {
        // if no new favicons, return
        return;
    }
    
    NSString *feedIdsQuery = [NSString stringWithFormat:@"?feed_ids=%@", 
                               [[keys valueForKey:@"description"] componentsJoinedByString:@"&feed_ids="]];        
    NSString *urlString = [NSString stringWithFormat:@"http://%@/reader/favicons%@",
                           NEWSBLUR_URL,
                           feedIdsQuery];
    NSURL *url = [NSURL URLWithString:urlString];
    ASIHTTPRequest  *request = [ASIHTTPRequest  requestWithURL:url];

    [request setDidFinishSelector:@selector(saveAndDrawFavicons:)];
    [request setDidFailSelector:@selector(requestFailed:)];
    [request setDelegate:self];
    [request startAsynchronous];
}

- (void)saveAndDrawFavicons:(ASIHTTPRequest *)request {

    NSString *responseString = [request responseString];
    NSData *responseData = [responseString dataUsingEncoding:NSUTF8StringEncoding];    
    NSError *error;
    NSDictionary *results = [NSJSONSerialization 
                             JSONObjectWithData:responseData
                             options:kNilOptions 
                             error:&error];
    
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0ul);
    dispatch_async(queue, ^{
        for (id feed_id in results) {
            NSMutableDictionary *feed = [[appDelegate.dictActiveFeeds objectForKey:feed_id] mutableCopy];
            [feed setValue:[results objectForKey:feed_id] forKey:@"favicon"];
            [appDelegate.dictActiveFeeds setValue:feed forKey:feed_id];
            
            NSString *favicon = [feed objectForKey:@"favicon"];
            if ((NSNull *)favicon != [NSNull null] && [favicon length] > 0) {
                NSData *imageData = [NSData dataWithBase64EncodedString:favicon];
                UIImage *faviconImage = [UIImage imageWithData:imageData];
                [Utilities saveImage:faviconImage feedId:feed_id];
            }
        }
        [Utilities saveimagesToDisk];
        
        dispatch_sync(dispatch_get_main_queue(), ^{
            [self.storyTitlesTable reloadData];
        });
    });
    
}

- (void)requestFailed:(ASIHTTPRequest *)request {
    NSError *error = [request error];
    NSLog(@"Error: %@", error);
}

#pragma mark -
#pragma mark WEPopoverControllerDelegate implementation

- (void)popoverControllerDidDismissPopover:(WEPopoverController *)thePopoverController {
	//Safe to release the popover here
	self.popoverController = nil;
}

- (BOOL)popoverControllerShouldDismissPopover:(WEPopoverController *)thePopoverController {
	//The popover is automatically dismissed if you click outside it, unless you return NO here
	return YES;
}

- (WEPopoverContainerViewProperties *)improvedContainerViewProperties {
	
	WEPopoverContainerViewProperties *props = [WEPopoverContainerViewProperties alloc];
	NSString *bgImageName = nil;
	CGFloat bgMargin = 0.0;
	CGFloat bgCapSize = 0.0;
	CGFloat contentMargin = 5.0;
	
	bgImageName = @"popoverBg.png";
	
	// These constants are determined by the popoverBg.png image file and are image dependent
	bgMargin = 13; // margin width of 13 pixels on all sides popoverBg.png (62 pixels wide - 36 pixel background) / 2 == 26 / 2 == 13
	bgCapSize = 31; // ImageSize/2  == 62 / 2 == 31 pixels
	
	props.leftBgMargin = bgMargin;
	props.rightBgMargin = bgMargin;
	props.topBgMargin = bgMargin;
	props.bottomBgMargin = bgMargin;
	props.leftBgCapSize = bgCapSize;
	props.topBgCapSize = bgCapSize;
	props.bgImageName = bgImageName;
	props.leftContentMargin = contentMargin;
	props.rightContentMargin = contentMargin - 1; // Need to shift one pixel for border to look correct
	props.topContentMargin = contentMargin;
	props.bottomContentMargin = contentMargin;
	
	props.arrowMargin = 4.0;
	
	props.upArrowImageName = @"popoverArrowUp.png";
	props.downArrowImageName = @"popoverArrowDown.png";
	props.leftArrowImageName = @"popoverArrowLeft.png";
	props.rightArrowImageName = @"popoverArrowRight.png";
	return props;
}

- (void)resetToolbar {
    self.navigationItem.leftBarButtonItem = nil;
    self.navigationItem.titleView = nil;
    self.navigationItem.rightBarButtonItem = nil;
}


@end
