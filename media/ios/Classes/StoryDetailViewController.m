//
//  StoryDetailViewController.m
//  NewsBlur
//
//  Created by Samuel Clay on 6/24/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import "StoryDetailViewController.h"
#import "NewsBlurAppDelegate.h"
#import "NewsBlurViewController.h"
#import "FeedDetailViewController.h"
#import "FontSettingsViewController.h"
#import "UserProfileViewController.h"
#import "ShareViewController.h"
#import "StoryPageControl.h"
#import "ASIHTTPRequest.h"
#import "ASIFormDataRequest.h"
#import "Base64.h"
#import "Utilities.h"
#import "NSString+HTML.h"
#import "NBContainerViewController.h"
#import "DataUtilities.h"
#import "JSON.h"
#import "SHK.h"
#import "StringHelper.h"

@implementation StoryDetailViewController

@synthesize appDelegate;
@synthesize activeStoryId;
@synthesize activeStory;
@synthesize innerView;
@synthesize webView;
@synthesize feedTitleGradient;
@synthesize noStorySelectedLabel;
@synthesize pullingScrollview;
@synthesize pageIndex;
@synthesize storyHUD;



#pragma mark -
#pragma mark View boilerplate

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
	
    if ((self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil])) {
    }
    return self;
}


- (void)viewDidLoad {
    [super viewDidLoad];
    

    // settings button to right
//    UIImage *settingsImage = [UIImage imageNamed:@"settings.png"];
//    UIButton *settings = [UIButton buttonWithType:UIButtonTypeCustom];    
//    settings.bounds = CGRectMake(0, 0, 32, 32);
//    [settings addTarget:self action:@selector(toggleFontSize:) forControlEvents:UIControlEventTouchUpInside];
//    [settings setImage:settingsImage forState:UIControlStateNormal];
//    
//    UIBarButtonItem *settingsButton = [[UIBarButtonItem alloc] 
//                                       initWithCustomView:settings];

    self.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    
    self.webView.scalesPageToFit = YES;
    self.webView.multipleTouchEnabled = NO;
    self.pageIndex = -2;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    return YES;
}

- (void)viewDidUnload {
    [self setInnerView:nil];
    [self setNoStorySelectedLabel:nil];
    [super viewDidUnload];
}

- (void)viewDidDisappear:(BOOL)animated {
//    Class viewClass = [appDelegate.navigationController.visibleViewController class];
//    if (viewClass == [appDelegate.feedDetailViewController class] ||
//        viewClass == [appDelegate.feedsViewController class]) {
////        self.activeStoryId = nil;
//        [webView loadHTMLString:@"" baseURL:[NSURL URLWithString:@""]];
//    }
}

- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration {
//    [appDelegate.shareViewController.commentField resignFirstResponder];
}

#pragma mark -
#pragma mark Story setup

- (void)initStory {
    
    appDelegate.inStoryDetail = YES;
    self.noStorySelectedLabel.hidden = YES;
    appDelegate.shareViewController.commentField.text = nil;
    self.webView.hidden = NO;

    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        [appDelegate.masterContainerViewController transitionFromShareView];
    }
    
    [appDelegate hideShareView:YES];
    [appDelegate resetShareComments];
}

- (void)drawStory {
    if (self.activeStoryId == [self.activeStory objectForKey:@"id"]) {
        NSLog(@"Already drawn story. Ignoring.");
//        return;
    }
    
    NSString *shareBarString = [self getShareBar];
    NSString *commentString = [self getComments];
    NSString *headerString;
    NSString *sharingHtmlString;
    NSString *footerString;
    NSString *fontStyleClass = @"";
    NSString *fontSizeClass = @"";
    
    NSUserDefaults *userPreferences = [NSUserDefaults standardUserDefaults];
    if ([userPreferences stringForKey:@"fontStyle"]){
        fontStyleClass = [fontStyleClass stringByAppendingString:[userPreferences stringForKey:@"fontStyle"]];
    } else {
        fontStyleClass = [fontStyleClass stringByAppendingString:@"NB-san-serif"];
    }
    if ([userPreferences stringForKey:@"fontSizing"]){
        fontSizeClass = [fontSizeClass stringByAppendingString:[userPreferences stringForKey:@"fontSizing"]];
    } else {
        fontSizeClass = [fontSizeClass stringByAppendingString:@"NB-medium"];
    }
    
    int contentWidth = self.appDelegate.storyPageControl.view.frame.size.width;
    NSString *contentWidthClass;
    
    if (contentWidth > 700) {
        contentWidthClass = @"NB-ipad-wide";
    } else if (contentWidth > 480) {
        contentWidthClass = @"NB-ipad-narrow";
    } else {
        contentWidthClass = @"NB-iphone";
    }
    
    // set up layout values based on iPad/iPhone
    headerString = [NSString stringWithFormat:@
                    "<link rel=\"stylesheet\" type=\"text/css\" href=\"reader.css\" >"
                    "<link rel=\"stylesheet\" type=\"text/css\" href=\"storyDetailView.css\" >"
                    "<meta name=\"viewport\" id=\"viewport\" content=\"width=%i, initial-scale=1.0, maximum-scale=1.0, user-scalable=no\"/>",
                    
                    
                    contentWidth];
    footerString = [NSString stringWithFormat:@
                    "<script src=\"zepto.js\"></script>"
                    "<script src=\"storyDetailView.js\"></script>"];
    
    sharingHtmlString = [NSString stringWithFormat:@
                         "<div class='NB-share-header'></div>"
                         "<div class='NB-share-wrapper'><div class='NB-share-inner-wrapper'>"
                         "<div id=\"NB-share-button-id\" class='NB-share-button NB-button'>"
                         "<a href=\"http://ios.newsblur.com/share\"><div>"
                         "Share this story <span class=\"NB-share-icon\"></span>"
                         "</div></a>"
                         "</div>"
                         "</div></div>"];

    NSString *storyHeader = [self getHeader];
    NSString *htmlString = [NSString stringWithFormat:@
                            "<html>"
                            "<head>%@</head>" // header string
                            "<body id=\"story_pane\" class=\"%@\">"
                            "    <div id=\"NB-header-container\">%@</div>" // storyHeader
                            "    %@" // shareBar
                            "    <div class=\"%@\" id=\"NB-font-style\">"
                            "       <div class=\"%@\" id=\"NB-font-size\">"
                            "           <div class=\"NB-story\">%@</div>"
                            "       </div>" // font-size
                            "    </div>" // font-style
                            "    %@" // share
                            "    <div id=\"NB-comments-wrapper\">"
                            "       %@" // friends comments
                            "    </div>"
                            "    %@"
                            "</body>"
                            "</html>",
                            headerString,
                            contentWidthClass,
                            storyHeader,
                            shareBarString,
                            fontStyleClass,
                            fontSizeClass,
                            [self.activeStory objectForKey:@"story_content"],
                            sharingHtmlString,
                            commentString,
                            footerString
                            ];
    
    //    NSLog(@"\n\n\n\nhtmlString:\n\n\n%@\n\n\n", htmlString);
    NSString *path = [[NSBundle mainBundle] bundlePath];
    NSURL *baseURL = [NSURL fileURLWithPath:path];
    
    [webView loadHTMLString:htmlString baseURL:baseURL];

    NSDictionary *feed;
    NSString *feedIdStr = [NSString stringWithFormat:@"%@",
                           [self.activeStory
                            objectForKey:@"story_feed_id"]];
    
    if (appDelegate.isSocialView || appDelegate.isSocialRiverView) {
        feed = [appDelegate.dictActiveFeeds objectForKey:feedIdStr];
        // this is to catch when a user is already subscribed
        if (!feed) {
            feed = [appDelegate.dictFeeds objectForKey:feedIdStr];
        }
    } else {
        feed = [appDelegate.dictFeeds objectForKey:feedIdStr];
    }
    
    self.feedTitleGradient = [appDelegate
                              makeFeedTitleGradient:feed
                              withRect:CGRectMake(0, -1, self.view.frame.size.width, 21)]; // 1024 hack for self.webView.frame.size.width
    
    self.feedTitleGradient.tag = FEED_TITLE_GRADIENT_TAG; // Not attached yet. Remove old gradients, first.
    [self.feedTitleGradient.layer setShadowColor:[[UIColor blackColor] CGColor]];
    [self.feedTitleGradient.layer setShadowOffset:CGSizeMake(0, 0)];
    [self.feedTitleGradient.layer setShadowOpacity:0];
    [self.feedTitleGradient.layer setShadowRadius:12.0];
    
    for (UIView *subview in self.webView.subviews) {
        if (subview.tag == FEED_TITLE_GRADIENT_TAG) {
            [subview removeFromSuperview];
        }
    }
    
    if (appDelegate.isRiverView || appDelegate.isSocialView) {
        self.webView.scrollView.contentInset = UIEdgeInsetsMake(20, 0, 0, 0);
        self.webView.scrollView.scrollIndicatorInsets = UIEdgeInsetsMake(20, 0, 0, 0);
    } else {
        self.webView.scrollView.contentInset = UIEdgeInsetsMake(9, 0, 0, 0);
        self.webView.scrollView.scrollIndicatorInsets = UIEdgeInsetsMake(9, 0, 0, 0);
    }
    [self.webView insertSubview:feedTitleGradient aboveSubview:self.webView.scrollView];
    //    [self.webView.scrollView setContentOffset:CGPointMake(0, (appDelegate.isRiverView ||
    //                                                              appDelegate.isSocialView) ? -20 : -9)
    //                                     animated:NO];
    [self.webView.scrollView addObserver:self forKeyPath:@"contentOffset"
                                 options:NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld
                                 context:nil];

    self.activeStoryId = [self.activeStory objectForKey:@"id"];
}

- (void)showStory {
    id storyId = [self.activeStory objectForKey:@"id"];
    [appDelegate pushReadStory:storyId];
}

- (void)clearStory {
    self.activeStoryId = nil;
    [self.webView loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:@"about:blank"]]];
}

- (void)hideStory {
    self.activeStoryId = nil;
    self.webView.hidden = YES;
    self.noStorySelectedLabel.hidden = NO;
}

#pragma mark -
#pragma mark Story layout

- (NSString *)getHeader {
    NSString *story_author = @"";
    if ([self.activeStory objectForKey:@"story_authors"]) {
        NSString *author = [NSString stringWithFormat:@"%@",
                            [self.activeStory objectForKey:@"story_authors"]];
        if (author && ![author isEqualToString:@"<null>"]) {
            int author_score = [[[appDelegate.activeClassifiers objectForKey:@"authors"] objectForKey:author] intValue];
            story_author = [NSString stringWithFormat:@"<a href=\"http://ios.newsblur.com/classify-author/%@\" "
                            "class=\"NB-story-author %@\"><div class=\"NB-highlight\"></div>%@</a>",
                            author,
                            author_score > 0 ? @"NB-story-author-positive" : author_score < 0 ? @"NB-story-author-negative" : @"",
                            author];
        }
    }
    NSString *story_tags = @"";
    if ([self.activeStory objectForKey:@"story_tags"]) {
        NSArray *tag_array = [self.activeStory objectForKey:@"story_tags"];
        if ([tag_array count] > 0) {
            NSMutableArray *tag_strings = [NSMutableArray array];
            for (NSString *tag in tag_array) {
                int tag_score = [[[appDelegate.activeClassifiers objectForKey:@"tags"] objectForKey:tag] intValue];
                NSString *tag_html = [NSString stringWithFormat:@"<a href=\"http://ios.newsblur.com/classify-tag/%@\" "
                                      "class=\"NB-story-tag %@\"><div class=\"NB-highlight\"></div>%@</a>",
                                      tag,
                                      tag_score > 0 ? @"NB-story-tag-positive" : tag_score < 0 ? @"NB-story-tag-negative" : @"",
                                      tag];
                [tag_strings addObject:tag_html];
            }
            story_tags = [NSString
                          stringWithFormat:@"<div id=\"NB-story-tags\" class=\"NB-story-tags\">"
                          "%@"
                          "</div>",
                          [tag_strings componentsJoinedByString:@""]];
        }
    }
    
    NSString *story_title = [self.activeStory objectForKey:@"story_title"];
    for (NSString *title_classifier in [appDelegate.activeClassifiers objectForKey:@"titles"]) {
        if ([story_title containsString:title_classifier]) {
            int title_score = [[[appDelegate.activeClassifiers objectForKey:@"titles"]
                                objectForKey:title_classifier] intValue];
            story_title = [story_title
                           stringByReplacingOccurrencesOfString:title_classifier
                           withString:[NSString stringWithFormat:@"<span class=\"NB-story-title-%@\">%@</span>",
                                       title_score > 0 ? @"positive" : title_score < 0 ? @"negative" : @"",
                                       title_classifier]];
        }
    }
    
    NSString *storyHeader = [NSString stringWithFormat:@
                             "<div class=\"NB-header\"><div class=\"NB-header-inner\">"
                             "<div class=\"NB-story-date\">%@</div>"
                             "<div class=\"NB-story-title\">%@</div>"
                             "%@"
                             "%@"
                             "</div></div>",
                             [story_tags length] ?
                             [self.activeStory objectForKey:@"long_parsed_date"] :
                             [self.activeStory objectForKey:@"short_parsed_date"],
                             story_title,
                             story_author,
                             story_tags];
    return storyHeader;
}

- (NSString *)getAvatars:(NSString *)key {
    NSString *avatarString = @"";
    NSArray *share_user_ids = [self.activeStory objectForKey:key];
    
    for (int i = 0; i < share_user_ids.count; i++) {
        NSDictionary *user = [self getUser:[[share_user_ids objectAtIndex:i] intValue]];
        NSString *avatarClass = @"NB-user-avatar";
        if ([key isEqualToString:@"commented_by_public"] ||
            [key isEqualToString:@"shared_by_public"]) {
            avatarClass = @"NB-public-user NB-user-avatar";
        }
        NSString *avatar = [NSString stringWithFormat:@
                            "<div class=\"NB-story-share-profile\"><div class=\"%@\">"
                            "<a id=\"NB-user-share-bar-%@\" class=\"NB-show-profile\" "
                            " href=\"http://ios.newsblur.com/show-profile/%@\"><img src=\"%@\" /></a>"
                            "</div></div>",
                            avatarClass,
                            [user objectForKey:@"user_id"],
                            [user objectForKey:@"user_id"],
                            [user objectForKey:@"photo_url"]];
        avatarString = [avatarString stringByAppendingString:avatar];
    }

    return avatarString;
}

- (NSString *)getComments {
    NSString *comments = @"<div class=\"NB-feed-story-comments\">";

    if ([self.activeStory objectForKey:@"share_count"] != [NSNull null] &&
        [[self.activeStory objectForKey:@"share_count"] intValue] > 0) {
        
        NSDictionary *story = self.activeStory;
        NSArray *friendsCommentsArray =  [story objectForKey:@"friend_comments"];   
        NSArray *publicCommentsArray =  [story objectForKey:@"public_comments"];   

        // add friends comments
        for (int i = 0; i < friendsCommentsArray.count; i++) {
            NSString *comment = [self getComment:[friendsCommentsArray objectAtIndex:i]];
            comments = [comments stringByAppendingString:comment];
        }
        
        if ([[story objectForKey:@"comment_count_public"] intValue] > 0 ) {
            NSString *publicCommentHeader = [NSString stringWithFormat:@
                                             "<div class=\"NB-story-comments-public-header-wrapper\">"
                                             "<div class=\"NB-story-comments-public-header\">%i public comment%@</div>"
                                             "</div>",
                                             [[story objectForKey:@"comment_count_public"] intValue],
                                             [[story objectForKey:@"comment_count_public"] intValue] == 1 ? @"" : @"s"];
            
            comments = [comments stringByAppendingString:publicCommentHeader];
            
            // add friends comments
            for (int i = 0; i < publicCommentsArray.count; i++) {
                NSString *comment = [self getComment:[publicCommentsArray objectAtIndex:i]];
                comments = [comments stringByAppendingString:comment];
            }
        }


        comments = [comments stringByAppendingString:[NSString stringWithFormat:@"</div>"]];
    }
    
    return comments;
}

- (NSString *)getShareBar {
    NSString *comments = @"<div id=\"NB-share-bar-wrapper\">";
    NSString *commentLabel = @"";
    NSString *shareLabel = @"";
//    NSString *replyStr = @"";
    
//    if ([[self.activeStory objectForKey:@"reply_count"] intValue] == 1) {
//        replyStr = [NSString stringWithFormat:@" and <b>1 reply</b>"];        
//    } else if ([[self.activeStory objectForKey:@"reply_count"] intValue] == 1) {
//        replyStr = [NSString stringWithFormat:@" and <b>%@ replies</b>", [self.activeStory objectForKey:@"reply_count"]];
//    }
    if (![[self.activeStory objectForKey:@"comment_count"] isKindOfClass:[NSNull class]] &&
        [[self.activeStory objectForKey:@"comment_count"] intValue]) {
        commentLabel = [commentLabel stringByAppendingString:[NSString stringWithFormat:@
                                                              "<div class=\"NB-story-comments-label\">"
                                                              "%@" // comment count
                                                              //"%@" // reply count
                                                              "</div>"
                                                              "<div class=\"NB-story-share-profiles NB-story-share-profiles-comments\">"
                                                              "%@" // friend avatars
                                                              "%@" // public avatars
                                                              "</div>",
                                                              [[self.activeStory objectForKey:@"comment_count"] intValue] == 1
                                                              ? [NSString stringWithFormat:@"<b>1 comment</b>"] : 
                                                              [NSString stringWithFormat:@"<b>%@ comments</b>", [self.activeStory objectForKey:@"comment_count"]],
                                                              
                                                              //replyStr,
                                                              [self getAvatars:@"commented_by_friends"],
                                                              [self getAvatars:@"commented_by_public"]]];
    }
    
    if (![[self.activeStory objectForKey:@"share_count"] isKindOfClass:[NSNull class]] &&
        [[self.activeStory objectForKey:@"share_count"] intValue]) {
        shareLabel = [shareLabel stringByAppendingString:[NSString stringWithFormat:@

                                                              "<div class=\"NB-right\">"
                                                                "<div class=\"NB-story-share-profiles NB-story-share-profiles-shares\">"
                                                                  "%@" // friend avatars
                                                                  "%@" // public avatars
                                                                "</div>"
                                                              "<div class=\"NB-story-share-label\">"
                                                              "%@" // comment count
                                                              "</div>"
                                                              "</div>",
                                                              [self getAvatars:@"shared_by_public"],
                                                              [self getAvatars:@"shared_by_friends"],
                                                              [[self.activeStory objectForKey:@"share_count"] intValue] == 1
                                                              ? [NSString stringWithFormat:@"<b>1 share</b>"] : 
                                                              [NSString stringWithFormat:@"<b>%@ shares</b>", [self.activeStory objectForKey:@"share_count"]]]];
    }
    
    if ([self.activeStory objectForKey:@"share_count"] != [NSNull null] &&
        [[self.activeStory objectForKey:@"share_count"] intValue] > 0) {
        
        comments = [comments stringByAppendingString:[NSString stringWithFormat:@
                                                      "<div class=\"NB-story-shares\">"
                                                      "<div class=\"NB-story-comments-shares-teaser-wrapper\">"
                                                      "<div class=\"NB-story-comments-shares-teaser\">"
                                                      "%@"
                                                      "%@"
                                                      "</div></div></div></div>",
                                                      commentLabel,
                                                      shareLabel
                                                      ]];

        
        

        comments = [comments stringByAppendingString:[NSString stringWithFormat:@"</div>"]];
    }
    comments = [comments stringByAppendingString:[NSString stringWithFormat:@"</div>"]];
    return comments;
}

- (NSString *)getComment:(NSDictionary *)commentDict {
    
    NSDictionary *user = [self getUser:[[commentDict objectForKey:@"user_id"] intValue]];
    NSString *userAvatarClass = @"NB-user-avatar";
    NSString *userReshareString = @"";
    NSString *userEditButton = @"";
    NSString *userLikeButton = @"";
    NSString *commentUserId = [NSString stringWithFormat:@"%@", [commentDict objectForKey:@"user_id"]];
    NSString *currentUserId = [NSString stringWithFormat:@"%@", [appDelegate.dictUserProfile objectForKey:@"user_id"]];
    NSArray *likingUsers = [commentDict objectForKey:@"liking_users"];
    

    
    if ([commentUserId isEqualToString:currentUserId]) {
        userEditButton = [NSString stringWithFormat:@
                          "<div class=\"NB-story-comment-edit-button NB-story-comment-share-edit-button NB-button\">"
                            "<a href=\"http://ios.newsblur.com/edit-share/%@\"><div class=\"NB-story-comment-edit-button-wrapper\">"
                                "Edit"
                            "</div></a>"
                          "</div>",
                          commentUserId];
    } else {
        BOOL isInLikingUsers = NO;
        for (int i = 0; i < likingUsers.count; i++) {
            if ([[[likingUsers objectAtIndex:i] stringValue] isEqualToString:currentUserId]) {
                isInLikingUsers = YES;
                break;
            }
        }
        
        if (isInLikingUsers) {
            userLikeButton = [NSString stringWithFormat:@
                              "<div class=\"NB-story-comment-like-button NB-button selected\">"
                              "<a href=\"http://ios.newsblur.com/unlike-comment/%@\"><div class=\"NB-story-comment-like-button-wrapper\">"
                              "<span class=\"NB-favorite-icon\"></span>Favorited"
                              "</div></a>"
                              "</div>",
                              commentUserId]; 
        } else {
            userLikeButton = [NSString stringWithFormat:@
                              "<div class=\"NB-story-comment-like-button NB-button\">"
                              "<a href=\"http://ios.newsblur.com/like-comment/%@\"><div class=\"NB-story-comment-like-button-wrapper\">"
                              "<span class=\"NB-favorite-icon\"></span>Favorite"
                              "</div></a>"
                              "</div>",
                              commentUserId]; 
        }

    }

    if ([commentDict objectForKey:@"source_user_id"] != [NSNull null]) {
        userAvatarClass = @"NB-user-avatar NB-story-comment-reshare";

        NSDictionary *sourceUser = [self getUser:[[commentDict objectForKey:@"source_user_id"] intValue]];
        userReshareString = [NSString stringWithFormat:@
                             "<div class=\"NB-story-comment-reshares\">"
                             "    <div class=\"NB-story-share-profile\">"
                             "        <div class=\"NB-user-avatar\"><img src=\"%@\"></div>"
                             "    </div>"
                             "</div>",
                             [sourceUser objectForKey:@"photo_url"]];
    } 
    
    NSString *commentContent = [self textToHtml:[commentDict objectForKey:@"comments"]];
    
    NSString *comment;
    NSString *locationHtml = @"";
    NSString *location = [NSString stringWithFormat:@"%@", [user objectForKey:@"location"]];
    
    if (location.length) {
        locationHtml = [NSString stringWithFormat:@"<div class=\"NB-story-comment-location\">%@</div>", location];
    }
    
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        comment = [NSString stringWithFormat:@
                    "<div class=\"NB-story-comment\" id=\"NB-user-comment-%@\">"
                    "<div class=\"%@\"><a class=\"NB-show-profile\" href=\"http://ios.newsblur.com/show-profile/%@\"><img src=\"%@\" /></a></div>"
                    "<div class=\"NB-story-comment-author-container\">"
                    "   %@"
                    "    <div class=\"NB-story-comment-username\">%@</div>"
                    " %@" // location
                    "    <div class=\"NB-story-comment-date\">%@ ago</div>"
                    "    <div class=\"NB-button-wrapper\">"
                    "    %@" //User Like Button>"
                    "    %@" //User Edit Button>"
                    "    <div class=\"NB-story-comment-reply-button NB-button\">"
                    "        <a href=\"http://ios.newsblur.com/reply/%@/%@\"><div class=\"NB-story-comment-reply-button-wrapper\">"
                    "            Reply"
                    "        </div></a>"
                    "    </div>"
                    "    </div>"
                    "</div>"
                    "<div class=\"NB-story-comment-content\">%@</div>"
                    "%@"
                    "</div>",
                    [commentDict objectForKey:@"user_id"],
                    userAvatarClass,
                    [commentDict objectForKey:@"user_id"],
                    [user objectForKey:@"photo_url"],
                    userReshareString,
                    [user objectForKey:@"username"],
                    locationHtml,
                    [commentDict objectForKey:@"shared_date"],
                    userEditButton,
                    userLikeButton,
                    [commentDict objectForKey:@"user_id"],
                    [user objectForKey:@"username"],
                    commentContent,
                    [self getReplies:[commentDict objectForKey:@"replies"] forUserId:[commentDict objectForKey:@"user_id"]]]; 
    } else {
        comment = [NSString stringWithFormat:@
                   "<div class=\"NB-story-comment\" id=\"NB-user-comment-%@\">"
                   "<div class=\"%@\"><a class=\"NB-show-profile\" href=\"http://ios.newsblur.com/show-profile/%@\"><img src=\"%@\" /></a></div>"
                   "<div class=\"NB-story-comment-author-container\">"
                   "   %@"
                   "    <div class=\"NB-story-comment-username\">%@</div>"
                   "   %@"
                   "    <div class=\"NB-story-comment-date\">%@ ago</div>"
                   "</div>"
                   "<div class=\"NB-story-comment-content\">%@</div>"

                   "    <div class=\"NB-button-wrapper\" style=\"clear:both; padding-bottom: 8px;\">"
                   "    %@" //User Like Button>"
                   "    %@" //User Edit Button>"
                   "    <div class=\"NB-story-comment-reply-button NB-button\">"
                   "        <a href=\"http://ios.newsblur.com/reply/%@/%@\"><div class=\"NB-story-comment-reply-button-wrapper\">"
                   "            Reply"
                   "        </div></a>"
                   "    </div>"
                   "</div>"
                   "%@"
                   "</div>",
                   [commentDict objectForKey:@"user_id"],
                   userAvatarClass,
                   [commentDict objectForKey:@"user_id"],
                   [user objectForKey:@"photo_url"],
                   userReshareString,
                   [user objectForKey:@"username"],
                   locationHtml,
                   [commentDict objectForKey:@"shared_date"],
                   commentContent,
                   userEditButton,
                   userLikeButton,
                   [commentDict objectForKey:@"user_id"],
                   [user objectForKey:@"username"],
                   [self getReplies:[commentDict objectForKey:@"replies"] forUserId:[commentDict objectForKey:@"user_id"]]]; 

    }
    
    return comment;
}

- (NSString *)getReplies:(NSArray *)replies forUserId:(NSString *)commentUserId {
    NSString *repliesString = @"";
    if (replies.count > 0) {
        repliesString = [repliesString stringByAppendingString:@"<div class=\"NB-story-comment-replies\">"];
        for (int i = 0; i < replies.count; i++) {
            NSDictionary *replyDict = [replies objectAtIndex:i];
            NSDictionary *user = [self getUser:[[replyDict objectForKey:@"user_id"] intValue]];

            NSString *userEditButton = @"";
            NSString *replyUserId = [NSString stringWithFormat:@"%@", [replyDict objectForKey:@"user_id"]];
            NSString *replyId = [replyDict objectForKey:@"reply_id"];
            NSString *currentUserId = [NSString stringWithFormat:@"%@", [appDelegate.dictUserProfile objectForKey:@"user_id"]];
            
            if ([replyUserId isEqualToString:currentUserId]) {
                userEditButton = [NSString stringWithFormat:@
                                  "<div class=\"NB-story-comment-edit-button NB-story-comment-share-edit-button NB-button\">"
                                  "<a href=\"http://ios.newsblur.com/edit-reply/%@/%@/%@\">"
                                  "<div class=\"NB-story-comment-edit-button-wrapper\">"
                                  "Edit"
                                  "</div>"
                                  "</a>"
                                  "</div>",
                                  commentUserId,
                                  replyUserId,
                                  replyId
                                  ];
            }
            
            NSString *replyContent = [self textToHtml:[replyDict objectForKey:@"comments"]];
            
            NSString *locationHtml = @"";
            NSString *location = [NSString stringWithFormat:@"%@", [user objectForKey:@"location"]];
            
            if (location.length) {
                locationHtml = [NSString stringWithFormat:@"<div class=\"NB-story-comment-location\">%@</div>", location];
            }
                        
            NSString *reply;
            
            if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
                reply = [NSString stringWithFormat:@
                        "<div class=\"NB-story-comment-reply\" id=\"NB-user-comment-%@\">"
                        "   <a class=\"NB-show-profile\" href=\"http://ios.newsblur.com/show-profile/%@\">"
                        "       <img class=\"NB-story-comment-reply-photo\" src=\"%@\" />"
                        "   </a>"
                        "   <div class=\"NB-story-comment-username NB-story-comment-reply-username\">%@</div>"
                        "   %@"
                        "   <div class=\"NB-story-comment-date NB-story-comment-reply-date\">%@ ago</div>"
                        "    <div class=\"NB-button-wrapper\">"
                        "    %@" //User Edit Button>"
                        "    </div>"
                        "   <div class=\"NB-story-comment-reply-content\">%@</div>"
                        "</div>",
                       [replyDict objectForKey:@"reply_id"],
                       [user objectForKey:@"user_id"],  
                       [user objectForKey:@"photo_url"],
                       [user objectForKey:@"username"],
                       locationHtml,
                       [replyDict objectForKey:@"publish_date"],
                       userEditButton,
                       replyContent];
            } else {
                reply = [NSString stringWithFormat:@
                         "<div class=\"NB-story-comment-reply\" id=\"NB-user-comment-%@\">"
                         "   <a class=\"NB-show-profile\" href=\"http://ios.newsblur.com/show-profile/%@\">"
                         "       <img class=\"NB-story-comment-reply-photo\" src=\"%@\" />"
                         "   </a>"
                         "   <div class=\"NB-story-comment-username NB-story-comment-reply-username\">%@</div>"
                         "   %@"
                         "   <div class=\"NB-story-comment-date NB-story-comment-reply-date\">%@ ago</div>"
                         "   <div class=\"NB-story-comment-reply-content\">%@</div>"
                         "    <div style=\"clear:both;\" class=\"NB-button-wrapper\">"
                         "    %@" //User Edit Button>"
                         "    </div>"
                         "</div>",
                         [replyDict objectForKey:@"reply_id"],
                         [user objectForKey:@"user_id"],  
                         [user objectForKey:@"photo_url"],
                         [user objectForKey:@"username"],
                         locationHtml,
                         [replyDict objectForKey:@"publish_date"],
                         replyContent,
                         userEditButton];
            }
            repliesString = [repliesString stringByAppendingString:reply];
        }
        repliesString = [repliesString stringByAppendingString:@"</div>"];
    }
    return repliesString;
}

- (NSDictionary *)getUser:(int)user_id {
    for (int i = 0; i < appDelegate.activeFeedUserProfiles.count; i++) {
        if ([[[appDelegate.activeFeedUserProfiles objectAtIndex:i] objectForKey:@"user_id"] intValue] == user_id) {
            return [appDelegate.activeFeedUserProfiles objectAtIndex:i];
        }
    }
    return nil;
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    
    if (keyPath == @"contentOffset") {
        if (self.webView.scrollView.contentOffset.y < (-1 * self.feedTitleGradient.frame.size.height + 1)) {
            // Pulling
            if (!pullingScrollview) {
                pullingScrollview = YES;
                [self.feedTitleGradient.layer setShadowOpacity:.5];
                [self.webView insertSubview:self.feedTitleGradient belowSubview:self.webView.scrollView];
                
                for (id subview in self.webView.scrollView.subviews) {
                    UIImageView *imgView = [subview isKindOfClass:[UIImageView class]] ?
                    (UIImageView*)subview : nil;
                    // image views whose image is 1px wide are shadow images, hide them
                    if (imgView && imgView.image.size.width == 1) {
                        imgView.hidden = YES;
                    }
                }
            }
            float y = -1 * self.webView.scrollView.contentOffset.y - self.feedTitleGradient.frame.size.height;
            self.feedTitleGradient.frame = CGRectMake(0, y,
                                                      self.feedTitleGradient.frame.size.width,
                                                      self.feedTitleGradient.frame.size.height);
        } else {
            // Normal reading
            if (pullingScrollview) {
                pullingScrollview = NO;
                [self.feedTitleGradient.layer setShadowOpacity:0];
                [self.webView insertSubview:self.feedTitleGradient aboveSubview:self.webView.scrollView];
                
                self.feedTitleGradient.frame = CGRectMake(0, -1,
                                                          self.feedTitleGradient.frame.size.width,
                                                          self.feedTitleGradient.frame.size.height);
                
                for (id subview in self.webView.scrollView.subviews) {
                    UIImageView *imgView = [subview isKindOfClass:[UIImageView class]] ?
                    (UIImageView*)subview : nil;
                    // image views whose image is 1px wide are shadow images, hide them
                    if (imgView && imgView.image.size.width == 1) {
                        imgView.hidden = NO;
                    }
                }
            }
        }
    }
}

- (void)setActiveStoryAtIndex:(NSInteger)activeStoryIndex {
    if (activeStoryIndex >= 0) {
        self.activeStory = [appDelegate.activeFeedStories objectAtIndex:activeStoryIndex];
    } else {
        self.activeStory = appDelegate.activeStory;
    }
}

- (BOOL)webView:(UIWebView *)webView 
shouldStartLoadWithRequest:(NSURLRequest *)request 
 navigationType:(UIWebViewNavigationType)navigationType {
    NSURL *url = [request URL];
    NSArray *urlComponents = [url pathComponents];
    NSString *action = @"";
    if ([urlComponents count] > 1) {
         action = [NSString stringWithFormat:@"%@", [urlComponents objectAtIndex:1]];
    }
                              
    // HACK: Using ios.newsblur.com to intercept the javascript share, reply, and edit events.
    // the pathComponents do not work correctly unless it is a correctly formed url
    // Is there a better way?  Someone show me the light
    if ([[url host] isEqualToString: @"ios.newsblur.com"]){
        // reset the active comment
        appDelegate.activeComment = nil;
        appDelegate.activeShareType = action;
        
        if ([action isEqualToString:@"reply"] || 
            [action isEqualToString:@"edit-reply"] ||
            [action isEqualToString:@"edit-share"] ||
            [action isEqualToString:@"like-comment"] ||
            [action isEqualToString:@"unlike-comment"]) {

            // search for the comment from friends comments
            NSArray *friendComments = [self.activeStory objectForKey:@"friend_comments"];
            for (int i = 0; i < friendComments.count; i++) {
                NSString *userId = [NSString stringWithFormat:@"%@", 
                                    [[friendComments objectAtIndex:i] objectForKey:@"user_id"]];
                if([userId isEqualToString:[NSString stringWithFormat:@"%@", 
                                            [urlComponents objectAtIndex:2]]]){
                    appDelegate.activeComment = [friendComments objectAtIndex:i];
                }
            }
            
            if (appDelegate.activeComment == nil) {
                NSArray *publicComments = [self.activeStory objectForKey:@"public_comments"];
                for (int i = 0; i < publicComments.count; i++) {
                    NSString *userId = [NSString stringWithFormat:@"%@", 
                                        [[publicComments objectAtIndex:i] objectForKey:@"user_id"]];
                    if([userId isEqualToString:[NSString stringWithFormat:@"%@", 
                                                [urlComponents objectAtIndex:2]]]){
                        appDelegate.activeComment = [publicComments objectAtIndex:i];
                    }
                }
            }
            
            if (appDelegate.activeComment == nil) {
                NSLog(@"PROBLEM! the active comment was not found in friend or public comments");
                return NO;
            }
            
            if ([action isEqualToString:@"reply"]) {
                [appDelegate showShareView:@"reply"
                                 setUserId:[NSString stringWithFormat:@"%@", [urlComponents objectAtIndex:2]]
                               setUsername:[NSString stringWithFormat:@"%@", [urlComponents objectAtIndex:3]]
                                setReplyId:nil];
            } else if ([action isEqualToString:@"edit-reply"]) {
                [appDelegate showShareView:@"edit-reply"
                                 setUserId:[NSString stringWithFormat:@"%@", [urlComponents objectAtIndex:2]]
                               setUsername:nil
                                setReplyId:[NSString stringWithFormat:@"%@", [urlComponents objectAtIndex:4]]];
            } else if ([action isEqualToString:@"edit-share"]) {
                [appDelegate showShareView:@"edit-share"
                                 setUserId:nil
                               setUsername:nil
                                setReplyId:nil];
            } else if ([action isEqualToString:@"like-comment"]) {
                [self toggleLikeComment:YES];
            } else if ([action isEqualToString:@"unlike-comment"]) {
                [self toggleLikeComment:NO];
            }
            return NO; 
        } else if ([action isEqualToString:@"share"]) {
            [self openShareDialog];
            return NO;
        } else if ([action isEqualToString:@"classify-author"]) {
            NSString *author = [NSString stringWithFormat:@"%@", [urlComponents objectAtIndex:2]];
            [self toggleAuthorClassifier:author];
            return NO;
        } else if ([action isEqualToString:@"classify-tag"]) {
            NSString *tag = [NSString stringWithFormat:@"%@", [urlComponents objectAtIndex:2]];
            [self toggleTagClassifier:tag];
            return NO;
        } else if ([action isEqualToString:@"show-profile"]) {
            appDelegate.activeUserProfileId = [NSString stringWithFormat:@"%@", [urlComponents objectAtIndex:2]];
                        
            for (int i = 0; i < appDelegate.activeFeedUserProfiles.count; i++) {
                NSString *userId = [NSString stringWithFormat:@"%@", [[appDelegate.activeFeedUserProfiles objectAtIndex:i] objectForKey:@"user_id"]];
                if ([userId isEqualToString:appDelegate.activeUserProfileId]){
                    appDelegate.activeUserProfileName = [NSString stringWithFormat:@"%@", [[appDelegate.activeFeedUserProfiles objectAtIndex:i] objectForKey:@"username"]];
                    break;
                }
            }
            
            
            [self showUserProfile:[urlComponents objectAtIndex:2]
                      xCoordinate:[[urlComponents objectAtIndex:3] intValue] 
                      yCoordinate:[[urlComponents objectAtIndex:4] intValue] 
                            width:[[urlComponents objectAtIndex:5] intValue] 
                           height:[[urlComponents objectAtIndex:6] intValue]];
            return NO; 
        }
    }
    if (navigationType == UIWebViewNavigationTypeLinkClicked) {
        [appDelegate showOriginalStory:url];
        return NO;
    }
    return YES;
}

- (void)showUserProfile:(NSString *)userId xCoordinate:(int)x yCoordinate:(int)y width:(int)width height:(int)height {
    CGRect frame = CGRectZero;
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        // only adjust for the bar if user is scrolling
        if (appDelegate.isRiverView || appDelegate.isSocialView) {
            if (self.webView.scrollView.contentOffset.y == -20) {
                y = y + 20;
            }
        } else {
            if (self.webView.scrollView.contentOffset.y == -9) {
                y = y + 9;
            }
        }  
        
        frame = CGRectMake(x, y, width, height);
    } 
    [appDelegate showUserProfileModal:[NSValue valueWithCGRect:frame]];
}

- (void)webViewDidStartLoad:(UIWebView *)webView {
    NSUserDefaults *userPreferences = [NSUserDefaults standardUserDefaults];    
    if ([userPreferences integerForKey:@"fontSizing"]){
        [self changeFontSize:[userPreferences stringForKey:@"fontSizing"]];
    }

}

- (void)webViewDidFinishLoad:(UIWebView *)webView {
    [MBProgressHUD hideHUDForView:self.view animated:YES];
    NSUserDefaults *userPreferences = [NSUserDefaults standardUserDefaults];
    if ([userPreferences integerForKey:@"fontSizing"]){
        [self changeFontSize:[userPreferences stringForKey:@"fontSizing"]];
    }
    
    if ([appDelegate.activeFeedStories count] &&
        self.activeStoryId &&
        ![self.webView.request.URL.absoluteString isEqualToString:@"about:blank"]) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, .15 * NSEC_PER_SEC),
                       dispatch_get_current_queue(), ^{
            [self checkTryFeedStory];
        });
    }
}

- (void)checkTryFeedStory {
    // see if it's a tryfeed for animation
    if (!self.webView.hidden &&
        appDelegate.tryFeedCategory &&
        [[appDelegate.activeStory objectForKey:@"id"] isEqualToString:appDelegate.tryFeedStoryId]) {
        [MBProgressHUD hideHUDForView:appDelegate.storyPageControl.view animated:YES];
        
        if ([appDelegate.tryFeedCategory isEqualToString:@"comment_like"] ||
            [appDelegate.tryFeedCategory isEqualToString:@"comment_reply"]) {
            NSString *currentUserId = [NSString stringWithFormat:@"%@", [appDelegate.dictUserProfile objectForKey:@"user_id"]];
            NSString *jsFlashString = [[NSString alloc] initWithFormat:@"slideToComment('%@', true, true);", currentUserId];
            [self.webView stringByEvaluatingJavaScriptFromString:jsFlashString];
        } else if ([appDelegate.tryFeedCategory isEqualToString:@"story_reshare"] ||
                   [appDelegate.tryFeedCategory isEqualToString:@"reply_reply"]) {
            NSString *blurblogUserId = [NSString stringWithFormat:@"%@", [self.activeStory objectForKey:@"social_user_id"]];
            NSString *jsFlashString = [[NSString alloc] initWithFormat:@"slideToComment('%@', true, true);", blurblogUserId];
            [self.webView stringByEvaluatingJavaScriptFromString:jsFlashString];
        }
        appDelegate.tryFeedCategory = nil;
    }
}

- (void)setFontStyle:(NSString *)fontStyle {
    NSString *jsString;
    NSString *fontStyleStr;
    NSUserDefaults *userPreferences = [NSUserDefaults standardUserDefaults];
    
    if ([fontStyle isEqualToString:@"Helvetica"]) {
        [userPreferences setObject:@"NB-san-serif" forKey:@"fontStyle"];
        fontStyleStr = @"NB-san-serif";
    } else {
        [userPreferences setObject:@"NB-serif" forKey:@"fontStyle"];
        fontStyleStr = @"NB-serif";
    }
    [userPreferences synchronize];
    
    jsString = [NSString stringWithFormat:@
                "document.getElementById('NB-font-style').setAttribute('class', '%@')",
                fontStyleStr];
    
    [self.webView stringByEvaluatingJavaScriptFromString:jsString];
}

- (void)changeFontSize:(NSString *)fontSize {
    NSString *jsString = [[NSString alloc] initWithFormat:@"document.getElementById('NB-font-size').setAttribute('class', '%@')",
                          fontSize];
    
    [self.webView stringByEvaluatingJavaScriptFromString:jsString];
}

<<<<<<< HEAD
#pragma mark -
#pragma mark Actions
=======
- (void)markStoryAsRead {
//    NSLog(@"[appDelegate.activeStory objectForKey:@read_status] intValue] %i", [[appDelegate.activeStory objectForKey:@"read_status"] intValue]);
    if ([[appDelegate.activeStory objectForKey:@"read_status"] intValue] != 1) {
        
        [appDelegate markActiveStoryRead];

        NSString *urlString;        
        if (appDelegate.isSocialView || appDelegate.isSocialRiverView) {
            urlString = [NSString stringWithFormat:@"http://%@/reader/mark_social_stories_as_read",
                        NEWSBLUR_URL];
        } else {
            urlString = [NSString stringWithFormat:@"http://%@/reader/mark_story_as_read",
                         NEWSBLUR_URL];
        }

        NSURL *url = [NSURL URLWithString:urlString];
        ASIFormDataRequest *request = [ASIFormDataRequest requestWithURL:url];
        
        if (appDelegate.isSocialRiverView) {
            // grab the user id from the shared_by_friends
            NSArray *storyId = [NSArray arrayWithObject:[appDelegate.activeStory objectForKey:@"id"]];
            NSString *friendUserId;
            
            if ([[appDelegate.activeStory objectForKey:@"shared_by_friends"] count]) {
                friendUserId = [NSString stringWithFormat:@"%@", 
                                          [[appDelegate.activeStory objectForKey:@"shared_by_friends"] objectAtIndex:0]];
            } else {
                friendUserId = [NSString stringWithFormat:@"%@", 
                                          [[appDelegate.activeStory objectForKey:@"commented_by_friends"] objectAtIndex:0]];
            }

            NSDictionary *feedStory = [NSDictionary dictionaryWithObject:storyId 
                                                                  forKey:[NSString stringWithFormat:@"%@", 
                                                                          [appDelegate.activeStory objectForKey:@"story_feed_id"]]];
            
            NSDictionary *usersFeedsStories = [NSDictionary dictionaryWithObject:feedStory 
                                                                          forKey:friendUserId];
            
            [request setPostValue:[usersFeedsStories JSONRepresentation] forKey:@"users_feeds_stories"]; 
        } else if (appDelegate.isSocialView) {
            NSArray *storyId = [NSArray arrayWithObject:[appDelegate.activeStory objectForKey:@"id"]];
            NSDictionary *feedStory = [NSDictionary dictionaryWithObject:storyId 
                                                                     forKey:[NSString stringWithFormat:@"%@", 
                                                                             [appDelegate.activeStory objectForKey:@"story_feed_id"]]];
                                         
            NSDictionary *usersFeedsStories = [NSDictionary dictionaryWithObject:feedStory 
                                                                          forKey:[NSString stringWithFormat:@"%@",
                                                                                  [appDelegate.activeStory objectForKey:@"social_user_id"]]];
            
            [request setPostValue:[usersFeedsStories JSONRepresentation] forKey:@"users_feeds_stories"]; 
        } else {
            [request setPostValue:[appDelegate.activeStory 
                                   objectForKey:@"id"] 
                           forKey:@"story_id"];
            [request setPostValue:[appDelegate.activeStory 
                                   objectForKey:@"story_feed_id"] 
                           forKey:@"feed_id"]; 
        }
                         
        [request setDidFinishSelector:@selector(finishMarkAsRead:)];
        [request setDidFailSelector:@selector(requestFailed:)];
        [request setDelegate:self];
        [request startAsynchronous];
    }
}
>>>>>>> Failing marking a story as read in ios now shows an error.

- (void)toggleLikeComment:(BOOL)likeComment {
    [appDelegate.storyPageControl showShareHUD:@"Favoriting"];
    NSString *urlString;
    if (likeComment) {
        urlString = [NSString stringWithFormat:@"http://%@/social/like_comment",
                               NEWSBLUR_URL];
    } else {
        urlString = [NSString stringWithFormat:@"http://%@/social/remove_like_comment",
                               NEWSBLUR_URL];
    }
    
    NSURL *url = [NSURL URLWithString:urlString];
    ASIFormDataRequest *request = [ASIFormDataRequest requestWithURL:url];
    
    
    [request setPostValue:[self.activeStory
                   objectForKey:@"id"] 
           forKey:@"story_id"];
    [request setPostValue:[self.activeStory
                           objectForKey:@"story_feed_id"] 
                   forKey:@"story_feed_id"];
    

    [request setPostValue:[appDelegate.activeComment objectForKey:@"user_id"] forKey:@"comment_user_id"];
    
    [request setDidFinishSelector:@selector(finishLikeComment:)];
    [request setDidFailSelector:@selector(requestFailed:)];
    [request setDelegate:self];
    [request startAsynchronous];
}

- (void)finishLikeComment:(ASIHTTPRequest *)request {
    NSString *responseString = [request responseString];
    NSData *responseData=[responseString dataUsingEncoding:NSUTF8StringEncoding];    
    NSError *error;
    NSDictionary *results = [NSJSONSerialization 
                             JSONObjectWithData:responseData
                             options:kNilOptions 
                             error:&error];
    
    // add the comment into the activeStory dictionary
    NSDictionary *newStory = [DataUtilities updateComment:results for:appDelegate];

    // update the current story and the activeFeedStories
    appDelegate.activeStory = newStory;
    [self setActiveStoryAtIndex:-1];
    
    NSMutableArray *newActiveFeedStories = [[NSMutableArray alloc] init];
    
    for (int i = 0; i < appDelegate.activeFeedStories.count; i++)  {
        NSDictionary *feedStory = [appDelegate.activeFeedStories objectAtIndex:i];
        NSString *storyId = [NSString stringWithFormat:@"%@", [feedStory objectForKey:@"id"]];
        NSString *currentStoryId = [NSString stringWithFormat:@"%@", [self.activeStory objectForKey:@"id"]];
        if ([storyId isEqualToString: currentStoryId]){
            [newActiveFeedStories addObject:newStory];
        } else {
            [newActiveFeedStories addObject:[appDelegate.activeFeedStories objectAtIndex:i]];
        }
    }
    
    appDelegate.activeFeedStories = [NSArray arrayWithArray:newActiveFeedStories];
    
    [MBProgressHUD hideHUDForView:appDelegate.storyPageControl.view animated:NO];
    [self refreshComments:@"like"];
} 


- (void)requestFailed:(ASIHTTPRequest *)request {    
    NSLog(@"Error in story detail: %@", [request error]);
    NSString *error;
    if ([request error]) {
        error = [NSString stringWithFormat:@"%@", [request error]];
    } else {
        error = @"The server barfed!";
    }
    [self informError:error];
}

<<<<<<< HEAD
<<<<<<< HEAD
=======
- (void)requestFailedMarkAsRead:(ASIHTTPRequest *)request {
    [self informError:@"Failed marking as read"];
}

=======
>>>>>>> Revert "Failing marking a story as read in ios now shows an error."
- (void)finishMarkAsRead:(ASIHTTPRequest *)request {
    //    NSString *responseString = [request responseString];
    //    NSDictionary *results = [[NSDictionary alloc]
    //                             initWithDictionary:[responseString JSONValue]];
    //    NSLog(@"results in mark as read is %@", results);
}

- (void)openSendToDialog {
    NSURL *url = [NSURL URLWithString:[appDelegate.activeStory
                                       objectForKey:@"story_permalink"]];
    SHKItem *item = [SHKItem URL:url title:[appDelegate.activeStory
                                            objectForKey:@"story_title"]];
    SHKActionSheet *actionSheet = [SHKActionSheet actionSheetForItem:item];
    [actionSheet showInView:self.view];
}

>>>>>>> Failing marking a story as read in ios now shows an error.
- (void)openShareDialog {
    // test to see if the user has commented
    // search for the comment from friends comments
    NSArray *friendComments = [self.activeStory objectForKey:@"friend_comments"];
    NSString *currentUserId = [NSString stringWithFormat:@"%@", [appDelegate.dictUserProfile objectForKey:@"user_id"]];
    for (int i = 0; i < friendComments.count; i++) {
        NSString *userId = [NSString stringWithFormat:@"%@",
                            [[friendComments objectAtIndex:i] objectForKey:@"user_id"]];
        if([userId isEqualToString:currentUserId]){
            appDelegate.activeComment = [friendComments objectAtIndex:i];
        }
    }
    
    if (appDelegate.activeComment == nil) {
        [appDelegate showShareView:@"share"
                         setUserId:nil
                       setUsername:nil
                        setReplyId:nil];
    } else {
        [appDelegate showShareView:@"edit-share"
                         setUserId:nil
                       setUsername:nil
                        setReplyId:nil];
    }
}

# pragma mark
# pragma mark Subscribing to blurblog

- (void)subscribeToBlurblog {
    [appDelegate.storyPageControl showShareHUD:@"Following"];
    NSString *urlString = [NSString stringWithFormat:@"http://%@/social/follow",
                     NEWSBLUR_URL];
    
    NSURL *url = [NSURL URLWithString:urlString];
    ASIFormDataRequest *request = [ASIFormDataRequest requestWithURL:url];
    
    [request setPostValue:[appDelegate.activeFeed 
                           objectForKey:@"user_id"] 
                   forKey:@"user_id"];

    [request setDidFinishSelector:@selector(finishSubscribeToBlurblog:)];
    [request setDidFailSelector:@selector(requestFailed:)];
    [request setDelegate:self];
    [request startAsynchronous];
} 

- (void)finishSubscribeToBlurblog:(ASIHTTPRequest *)request {
    [MBProgressHUD hideHUDForView:appDelegate.storyPageControl.view animated:NO];
    self.storyHUD = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
    self.storyHUD.customView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"37x-Checkmark.png"]];
    self.storyHUD.mode = MBProgressHUDModeCustomView;
    self.storyHUD.removeFromSuperViewOnHide = YES;  
    self.storyHUD.labelText = @"Followed";
    [self.storyHUD hide:YES afterDelay:1];
    appDelegate.storyPageControl.navigationItem.leftBarButtonItem = nil;
    [appDelegate reloadFeedsView:NO];
//    [appDelegate.feedDetailViewController resetFeedDetail];
//    [appDelegate.feedDetailViewController fetchFeedDetail:1 withCallback:nil];
}

- (void)refreshComments:(NSString *)replyId {
    NSString *shareBarString = [self getShareBar];  
    
    NSString *commentString = [self getComments];  
    NSString *jsString = [[NSString alloc] initWithFormat:@
                          "document.getElementById('NB-comments-wrapper').innerHTML = '%@';"
                          "document.getElementById('NB-share-bar-wrapper').innerHTML = '%@';",
                          commentString, 
                          shareBarString];
    NSString *shareType = appDelegate.activeShareType;
    [self.webView stringByEvaluatingJavaScriptFromString:jsString];

    // HACK to make the scroll event happen after the replace innerHTML event above happens.
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, .15 * NSEC_PER_SEC),
                   dispatch_get_current_queue(), ^{
        if (!replyId) {
            NSString *currentUserId = [NSString stringWithFormat:@"%@",
                                       [appDelegate.dictUserProfile objectForKey:@"user_id"]];
            NSString *jsFlashString = [[NSString alloc]
                                       initWithFormat:@"slideToComment('%@', true);", currentUserId];
            [self.webView stringByEvaluatingJavaScriptFromString:jsFlashString];
        } else if ([replyId isEqualToString:@"like"]) {
            
        } else {
            NSString *jsFlashString = [[NSString alloc]
                                       initWithFormat:@"slideToComment('%@', true);", replyId];
            [self.webView stringByEvaluatingJavaScriptFromString:jsFlashString];
        }
    });
        

//    // adding in a simulated delay
//    sleep(1);
    
    self.storyHUD = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
    self.storyHUD.customView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"37x-Checkmark.png"]];
    self.storyHUD.mode = MBProgressHUDModeCustomView;
    self.storyHUD.removeFromSuperViewOnHide = YES;  

    if ([shareType isEqualToString:@"reply"]) {
        self.storyHUD.labelText = @"Replied";
    } else if ([shareType isEqualToString:@"edit-reply"]) {
        self.storyHUD.labelText = @"Edited Reply";
    } else if ([shareType isEqualToString:@"edit-share"]) {
        self.storyHUD.labelText = @"Edited Comment";
    } else if ([shareType isEqualToString:@"share"]) {
        self.storyHUD.labelText = @"Shared";
    } else if ([shareType isEqualToString:@"like-comment"]) {
        self.storyHUD.labelText = @"Favorited";
    } else if ([shareType isEqualToString:@"unlike-comment"]) {
        self.storyHUD.labelText = @"Unfavorited";
    }
    [self.storyHUD hide:YES afterDelay:1];
}

- (void)scrolltoComment {
    NSString *currentUserId = [NSString stringWithFormat:@"%@", [appDelegate.dictUserProfile objectForKey:@"user_id"]];
    NSString *jsFlashString = [[NSString alloc] initWithFormat:@"slideToComment('%@', true);", currentUserId];
    [self.webView stringByEvaluatingJavaScriptFromString:jsFlashString];
}

- (NSString *)textToHtml:(NSString*)htmlString {
    htmlString = [htmlString stringByReplacingOccurrencesOfString:@"'"  withString:@"&#039;"];
    htmlString = [htmlString stringByReplacingOccurrencesOfString:@"\n"  withString:@"<br/>"];
    return htmlString;
}

- (void)changeWebViewWidth {
    int contentWidth = self.appDelegate.storyPageControl.view.frame.size.width;
    NSString *contentWidthClass;
    
    if (contentWidth > 740) {
        contentWidthClass = @"NB-ipad-wide";
    } else if (contentWidth > 480) {
        contentWidthClass = @"NB-ipad-narrow";
    } else {
        contentWidthClass = @"NB-iphone";
    }
    
    NSString *jsString = [[NSString alloc] initWithFormat:
                          @"$('body').attr('class', '%@');"
                          "document.getElementById(\"viewport\").setAttribute(\"content\", \"width=%i;initial-scale=1; maximum-scale=1.0; user-scalable=0;\");",
                          contentWidthClass,
                          contentWidth];
    [self.webView stringByEvaluatingJavaScriptFromString:jsString];
    
//    self.webView.hidden = NO;
}

#pragma mark -
#pragma mark Classifiers

- (void)toggleAuthorClassifier:(NSString *)author {
    int author_score = [[[appDelegate.activeClassifiers objectForKey:@"authors"] objectForKey:author] intValue];
    if (author_score > 0) {
        author_score = -1;
    } else if (author_score < 0) {
        author_score = 0;
    } else {
        author_score = 1;
    }
    NSMutableDictionary *authors = [[appDelegate.activeClassifiers objectForKey:@"authors"] mutableCopy];
    [authors setObject:[NSNumber numberWithInt:author_score] forKey:author];
    [appDelegate.activeClassifiers setObject:authors forKey:@"authors"];
    [appDelegate.storyPageControl refreshHeaders];
    
    NSString *urlString = [NSString stringWithFormat:@"http://%@/classifier/save",
                           NEWSBLUR_URL];
    NSURL *url = [NSURL URLWithString:urlString];
    ASIFormDataRequest *request = [ASIFormDataRequest requestWithURL:url];
    [request setPostValue:author
                   forKey:author_score >= 1 ? @"like_author" :
                          author_score <= -1 ? @"dislike_author" :
                          @"remove_like_author"];
    [request setPostValue:[self.activeStory
                           objectForKey:@"story_feed_id"]
                   forKey:@"feed_id"];
    [request setDidFinishSelector:@selector(finishTrain:)];
    [request setDidFailSelector:@selector(requestFailed:)];
    [request setDelegate:self];
    [request startAsynchronous];
}

- (void)toggleTagClassifier:(NSString *)tag {
    int tag_score = [[[appDelegate.activeClassifiers objectForKey:@"tags"] objectForKey:tag] intValue];
    if (tag_score > 0) {
        tag_score = -1;
    } else if (tag_score < 0) {
        tag_score = 0;
    } else {
        tag_score = 1;
    }
    
    NSMutableDictionary *tags = [[appDelegate.activeClassifiers objectForKey:@"tags"] mutableCopy];
    [tags setObject:[NSNumber numberWithInt:tag_score] forKey:tag];
    [appDelegate.activeClassifiers setObject:tags forKey:@"tags"];
    [appDelegate.storyPageControl refreshHeaders];

    NSString *urlString = [NSString stringWithFormat:@"http://%@/classifier/save",
                           NEWSBLUR_URL];
    NSURL *url = [NSURL URLWithString:urlString];
    ASIFormDataRequest *request = [ASIFormDataRequest requestWithURL:url];
    [request setPostValue:tag
                   forKey:tag_score >= 1 ? @"like_tag" :
                          tag_score <= -1 ? @"dislike_tag" :
                          @"remove_like_tag"];
    [request setPostValue:[self.activeStory
                           objectForKey:@"story_feed_id"]
                   forKey:@"feed_id"];
    [request setDidFinishSelector:@selector(finishTrain:)];
    [request setDidFailSelector:@selector(requestFailed:)];
    [request setDelegate:self];
    [request startAsynchronous];
}

- (void)finishTrain:(ASIHTTPRequest *)request {
    [appDelegate.feedsViewController refreshFeedList:[self.activeStory
                                                      objectForKey:@"story_feed_id"]];
}

- (void)refreshHeader {
    NSString *headerString = [[self getHeader] stringByReplacingOccurrencesOfString:@"\'" withString:@"\\'"];
    NSString *jsString = [NSString stringWithFormat:@"document.getElementById('NB-header-container').innerHTML = '%@';",
                          headerString];
    [self.webView stringByEvaluatingJavaScriptFromString:jsString];
    
    [self.webView stringByEvaluatingJavaScriptFromString:@"attachFastClick();"];
}

@end
