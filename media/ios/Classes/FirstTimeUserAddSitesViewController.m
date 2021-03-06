//
//  FTUXaddSitesViewController.m
//  NewsBlur
//
//  Created by Roy Yang on 7/22/12.
//  Copyright (c) 2012 NewsBlur. All rights reserved.
//

#import "NewsBlurAppDelegate.h"
#import "FirstTimeUserAddSitesViewController.h"
#import "FirstTimeUserAddFriendsViewController.h"
#import "AuthorizeServicesViewController.h"
#import "NewsBlurViewController.h"
#import "SiteCell.h"
#import "Base64.h"

@interface FirstTimeUserAddSitesViewController()

@property (readwrite) int importedFeedCount_;
@property (nonatomic) UIButton *currentButton_;
@property (nonatomic, strong) NSMutableSet *selectedCategories_;
@property (readwrite) BOOL googleImportSuccess_;

@end;

@implementation FirstTimeUserAddSitesViewController

@synthesize appDelegate;
@synthesize googleReaderButton;
@synthesize nextButton;
@synthesize activityIndicator;
@synthesize instructionLabel;
@synthesize categoriesTable;
@synthesize scrollView;
@synthesize googleReaderButtonWrapper;
@synthesize importedFeedCount_;
@synthesize currentButton_;
@synthesize selectedCategories_;
@synthesize googleImportSuccess_;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad {
    self.selectedCategories_ = [[NSMutableSet alloc] init];
    
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.
    
    
    UIBarButtonItem *next = [[UIBarButtonItem alloc] initWithTitle:@"Next step" style:UIBarButtonSystemItemDone target:self action:@selector(tapNextButton)];
    self.nextButton = next;
    self.nextButton.enabled = NO;
    self.navigationItem.rightBarButtonItem = next;
    
    self.navigationItem.title = @"Add Sites";
    self.activityIndicator.hidesWhenStopped = YES;
    
    self.categoriesTable.delegate = self;
    self.categoriesTable.dataSource = self;
    self.categoriesTable.backgroundColor = [UIColor clearColor];
//    self.categoriesTable.separatorColor = [UIColor clearColor];
    self.categoriesTable.opaque = NO;
    self.categoriesTable.backgroundView = nil;
    
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone) {
        self.instructionLabel.font = [UIFont systemFontOfSize:14];
    }
    
    
    UIActivityIndicatorView *activityView = [[UIActivityIndicatorView alloc] 
                                             initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhite];
    activityView.frame = CGRectMake(68, 7, 20, 20.0);
    self.activityIndicator = activityView;
}

- (void)viewWillAppear:(BOOL)animated {
    [self.navigationItem.rightBarButtonItem setStyle:UIBarButtonItemStyleDone];
    [self.categoriesTable reloadData];
    [self.scrollView setContentSize:CGSizeMake(self.view.frame.size.width, self.tableViewHeight + 100)];
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        self.categoriesTable.frame = CGRectMake((self.view.frame.size.width - 300)/2, 60, self.categoriesTable.frame.size.width, self.tableViewHeight);        
    } else {
        self.categoriesTable.frame = CGRectMake(10, 60, self.categoriesTable.frame.size.width, self.tableViewHeight); 
    }
    
    NSLog(@"%f height", self.tableViewHeight);
}

- (void)viewDidUnload {
    [super viewDidUnload];
    [self setActivityIndicator:nil];
    [self setInstructionLabel:nil];
    [self setCategoriesTable:nil];
    [self setGoogleReaderButton:nil];
    [self setScrollView:nil];
    [self setNextButton:nil];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    // Return YES for supported orientations
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        return YES;
    } else if (UIInterfaceOrientationIsPortrait(interfaceOrientation)) {
        return YES;
    }
    return NO;
}


- (IBAction)tapNextButton {
    [appDelegate.ftuxNavigationController pushViewController:appDelegate.firstTimeUserAddFriendsViewController animated:YES];
    
    if (self.selectedCategories_.count) {
        NSString *urlString = [NSString stringWithFormat:@"http://%@/categories/subscribe",
                               NEWSBLUR_URL];
        NSURL *url = [NSURL URLWithString:urlString];
        ASIFormDataRequest *request = [ASIFormDataRequest requestWithURL:url];
        
        for(NSObject *category in self.selectedCategories_) {
            [request addPostValue:category forKey:@"category"];
        }

        [request setDelegate:self];
        [request setDidFinishSelector:@selector(finishAddingCategories:)];
        [request setDidFailSelector:@selector(requestFailed:)];
        [request startAsynchronous];
    }
}

- (void)finishAddingCategories:(ASIHTTPRequest *)request {
    NSString *responseString = [request responseString];
    NSData *responseData=[responseString dataUsingEncoding:NSUTF8StringEncoding];    
    NSError *error;
    NSDictionary *results = [NSJSONSerialization 
                             JSONObjectWithData:responseData
                             options:kNilOptions 
                             error:&error];
    NSLog(@"results are %@", results);
}
    
#pragma mark -
#pragma mark Import Google Reader

- (void)tapGoogleReaderButton {
    AuthorizeServicesViewController *service = [[AuthorizeServicesViewController alloc] init];
    service.url = @"/import/authorize";
    service.type = @"google";
    [appDelegate.ftuxNavigationController pushViewController:service animated:YES];
}

- (void)importFromGoogleReader {    
    UIView *header = [self.categoriesTable viewWithTag:0];
    UIButton *button = (UIButton *)[header viewWithTag:1000];
    self.googleReaderButton = button;

    self.nextButton.enabled = YES;
    [self.googleReaderButton setTitle:@"Importing sites..." forState:UIControlStateNormal];
    self.instructionLabel.textColor = UIColorFromRGB(0x333333);
    self.googleReaderButton.userInteractionEnabled = NO;
    self.instructionLabel.text = @"This might take a minute.  Feel free to continue...";
    [self.googleReaderButton addSubview:self.activityIndicator];
    [self.activityIndicator startAnimating];
    NSString *urlString = [NSString stringWithFormat:@"http://%@/import/import_from_google_reader/",
                           NEWSBLUR_URL];
    NSURL *url = [NSURL URLWithString:urlString];
    ASIFormDataRequest *request = [ASIFormDataRequest requestWithURL:url];
    [request setPostValue:@"true" forKey:@"auto_active"];
    [request setDelegate:self];
    [request setDidFinishSelector:@selector(finishImportFromGoogleReader:)];
    [request setDidFailSelector:@selector(requestFailed:)];
    [request startAsynchronous];
}

- (void)importFromGoogleReaderFailed:(NSString *)error {
    [self.googleReaderButton setTitle:@"Retry Google Reader" forState:UIControlStateNormal];
    self.instructionLabel.textColor = [UIColor redColor];
    self.instructionLabel.text = error;
}

- (void)finishImportFromGoogleReader:(ASIHTTPRequest *)request {
    NSString *responseString = [request responseString];
    NSData *responseData=[responseString dataUsingEncoding:NSUTF8StringEncoding];    
    NSError *error;
    NSDictionary *results = [NSJSONSerialization 
                             JSONObjectWithData:responseData
                             options:kNilOptions 
                             error:&error];
    NSLog(@"results are %@", results);
    
    self.importedFeedCount_ = [[results objectForKey:@"feed_count"] intValue];
    [self performSelector:@selector(updateSites) withObject:nil afterDelay:1];
    self.googleImportSuccess_ = YES;
}

- (void)updateSites {
    self.instructionLabel.text = @"And just like that, we're done!\nAdd more categories or move on...";
    NSString *msg = [NSString stringWithFormat:@"Imported %i site%@", 
                     self.importedFeedCount_,
                     self.importedFeedCount_ == 1 ? @"" : @"s"];
    [self.googleReaderButton setTitle:msg  forState:UIControlStateSelected];
    self.googleReaderButton.selected = YES;
    [self.activityIndicator stopAnimating];
    
    UIImage *checkmark = [UIImage imageNamed:@"258-checkmark"];
    UIImageView *checkmarkView = [[UIImageView alloc] initWithImage:checkmark];
    checkmarkView.frame = CGRectMake(self.googleReaderButton.frame.size.width - 24,
                                     8,
                                     16,
                                     16);
    [self.googleReaderButton addSubview:checkmarkView];
}

#pragma mark -
#pragma mark Add Categories

- (void)addCategory:(id)sender {
    NSInteger tag = ((UIControl *) sender).tag;

    // set the currentButton
    self.currentButton_ = (UIButton *)sender;
    if (tag == 1000) {
        [self tapGoogleReaderButton];
    } else {
        UIButton *button = (UIButton *)sender;
        NSLog(@"self.currentButton_.titleLabel.text is %@", self.currentButton_.titleLabel.text);
        if (button.selected) {
            [self.selectedCategories_ removeObject:self.currentButton_.titleLabel.text];
            
            self.nextButton.enabled = YES;
            button.selected = NO;
            UIImageView *imageView = (UIImageView*)[button viewWithTag:100];
            [imageView removeFromSuperview];
        } else {
            [self.selectedCategories_ addObject:self.currentButton_.titleLabel.text];
            button.selected = YES;
        }
    }
    if (self.googleImportSuccess_) {
        self.nextButton.enabled = YES;
    } else if (self.selectedCategories_.count) {
        self.nextButton.enabled = YES;
    } else {
        self.nextButton.enabled = NO;
    }
    
    NSIndexSet *indexSet = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(tag - 1000, 1)];

    [self.categoriesTable reloadSections:indexSet withRowAnimation:UITableViewRowAnimationNone];
}

- (void)finishAddFolder:(ASIHTTPRequest *)request {
    NSLog(@"Successfully added.");
}

- (void)requestFailed:(ASIHTTPRequest *)request {
    NSError *error = [request error];
    NSLog(@"Error: %@", error);
}

#pragma mark -
#pragma mark Add Site

- (void)addSite:(NSString *)siteUrl {
    NSString *urlString = [NSString stringWithFormat:@"http://%@/reader/add_url",
                           NEWSBLUR_URL];
    NSURL *url = [NSURL URLWithString:urlString];
    ASIFormDataRequest *request = [ASIFormDataRequest requestWithURL:url];
    
    [request setPostValue:siteUrl forKey:@"url"]; 
    
    [request setDelegate:self];
    [request setDidFinishSelector:@selector(finishAddFolder:)];
    [request setDidFailSelector:@selector(requestFailed:)];
    [request startAsynchronous];
}

#pragma mark -
#pragma mark Table View - Interactions List

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return appDelegate.categories.count + 1;
}

//- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
//{    
//    NSDictionary *category = [appDelegate.categories objectAtIndex:section];
//    return [category objectForKey:@"title"];
//}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {    
    if (section == 0 ) {
        return 1;
    } else {
        NSDictionary *category = [appDelegate.categories objectAtIndex:section - 1];
        NSArray *categorySiteList = [category objectForKey:@"feed_ids"];
        return categorySiteList.count;
    }
    return 0;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {        
    return 26;
}

- (CGFloat) tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    return 54.0;
}

- (UIView *)tableView:(UITableView *)tableView 
viewForHeaderInSection:(NSInteger)section {

    // create the parent view that will hold header Label
    UIView* customView = [[UIView alloc] initWithFrame:CGRectMake(0.0, 0.0, 300.0, 34.0)];
    customView.tag = section;
    
    
    UIImage *buttonImage =[[UIImage imageNamed:@"google.png"] stretchableImageWithLeftCapWidth:5.0 topCapHeight:0.0];
    UIButton *headerBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    headerBtn.tag = section + 1000;
    [headerBtn setBackgroundImage:buttonImage forState:UIControlStateNormal];
    headerBtn.titleLabel.font = [UIFont fontWithName:@"Helvetica-Bold" size:14];
    
    headerBtn.frame = CGRectMake(0, 20.0, 300, 34.0);
    headerBtn.titleLabel.shadowColor = UIColorFromRGB(0x1E5BDB);
    headerBtn.titleLabel.shadowOffset = CGSizeMake(0, 1);
    NSString *categoryTitle;
    if (section == 0) {
        categoryTitle = @"Google Reader";
    } else {
        NSDictionary *category = [appDelegate.categories objectAtIndex:section - 1];
        categoryTitle = [category objectForKey:@"title"];
        
        BOOL inSelect = [self.selectedCategories_ containsObject:[NSString stringWithFormat:@"%@", [category objectForKey:@"title"]]];
        NSLog(@"inselected %i", inSelect);
        if (inSelect) {
            headerBtn.selected = YES;
            UIImage *checkmark = [UIImage imageNamed:@"258-checkmark"];
            UIImageView *checkmarkView = [[UIImageView alloc] initWithImage:checkmark];
            checkmarkView.frame = CGRectMake(headerBtn.frame.origin.x + headerBtn.frame.size.width - 24,
                                             8,
                                             16,
                                             16);
            checkmarkView.tag = 100;
            [headerBtn addSubview:checkmarkView];
        }

    }
    

    [headerBtn setTitle:categoryTitle forState:UIControlStateNormal];

    [headerBtn addTarget:self action:@selector(addCategory:) forControlEvents:UIControlEventTouchUpInside];
    
       
    
    [customView addSubview:headerBtn];
    
    


    
    
    return customView;
}


- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    SiteCell *cell = [tableView 
                             dequeueReusableCellWithIdentifier:@"ActivityCell"];
    if (cell == nil) {
        cell = [[SiteCell alloc] 
                initWithStyle:UITableViewCellStyleDefault 
                reuseIdentifier:@"ActivityCell"];
    } 

    NSString *siteTitle;

    if (indexPath.section == 0 ) {
        siteTitle = @"Import your sites from Google Reader";
        cell.siteFavicon = nil;
        cell.feedColorBar = nil;
        cell.feedColorBarTopBorder = nil;
    } else {
        NSDictionary *category = [appDelegate.categories objectAtIndex:indexPath.section - 1];
        NSArray *categorySiteList = [category objectForKey:@"feed_ids"];
        NSString * feedId = [NSString stringWithFormat:@"%@", [categorySiteList objectAtIndex:indexPath.row ]];
        
        NSDictionary *feed = [appDelegate.categoryFeeds objectForKey:feedId];
        siteTitle = [feed objectForKey:@"feed_title"];
        
        BOOL inSelect = [self.selectedCategories_ containsObject:[NSString stringWithFormat:@"%@", [category objectForKey:@"title"]]];

        if (inSelect) {
            cell.isRead = NO;
        } else {
            cell.isRead = YES;
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
        
        NSString *faviconStr = [NSString stringWithFormat:@"%@", [feed valueForKey:@"favicon"]];
        NSData *imageData = [NSData dataWithBase64EncodedString:faviconStr];
        UIImage *faviconImage = [UIImage imageWithData:imageData];
        

        cell.siteFavicon = faviconImage;
    }

    cell.opaque = NO;
    cell.siteTitle = siteTitle; 
    
    return cell;
}

- (void)tableView:(UITableView *)tableView 
didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    UIView *header = [self.categoriesTable viewWithTag:indexPath.section];
    UIButton *button = (UIButton *)[header viewWithTag:indexPath.section + 1000];
    [button sendActionsForControlEvents:UIControlEventTouchUpInside];
}

-(NSIndexPath *)tableView:(UITableView *)tableView willSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    UIView *header = [self.categoriesTable viewWithTag:indexPath.section];
    UIButton *button = (UIButton *)[header viewWithTag:indexPath.section + 1000];
    [button sendActionsForControlEvents:UIControlStateSelected];
    return indexPath;
}

- (CGFloat)tableViewHeight {
    [self.categoriesTable layoutIfNeeded];
    return [self.categoriesTable contentSize].height;
}

@end
