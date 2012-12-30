//
//  FeedTableCell.m
//  NewsBlur
//
//  Created by Samuel Clay on 7/18/11.
//  Copyright 2011 NewsBlur. All rights reserved.
//

#import "NewsBlurAppDelegate.h"
#import "FeedTableCell.h"
#import "UnreadCountView.h"
#import "ABTableViewCell.h"

static UIFont *textFont = nil;

@implementation FeedTableCell

@synthesize appDelegate;
@synthesize feedTitle;
@synthesize feedFavicon;
@synthesize positiveCount = _positiveCount;
@synthesize neutralCount = _neutralCount;
@synthesize negativeCount = _negativeCount;
@synthesize negativeCountStr;
@synthesize isSocial;

+ (void) initialize{
    if (self == [FeedTableCell class]) {
        textFont = [UIFont boldSystemFontOfSize:18];
//        UIColor *psGrad = UIColorFromRGB(0x559F4D);
//        UIColor *ntGrad = UIColorFromRGB(0xE4AB00);
//        UIColor *ngGrad = UIColorFromRGB(0x9B181B);
//        const CGFloat* psTop = CGColorGetComponents(ps.CGColor);
//        const CGFloat* psBot = CGColorGetComponents(psGrad.CGColor);
//        CGFloat psGradient[] = {
//            psTop[0], psTop[1], psTop[2], psTop[3],
//            psBot[0], psBot[1], psBot[2], psBot[3]
//        };
//        psColors = psGradient;
    }
}


- (void) setPositiveCount:(int)ps {
    if (ps == _positiveCount) return;
    
    _positiveCount = ps;
    [self setNeedsDisplay];
}

- (void) setNeutralCount:(int)nt {
    if (nt == _neutralCount) return;
    
    _neutralCount = nt;
    [self setNeedsDisplay];
}

- (void) setNegativeCount:(int)ng {
    if (ng == _negativeCount) return;
    
    _negativeCount = ng;
    _negativeCountStr = [NSString stringWithFormat:@"%d", ng];
    [self setNeedsDisplay];
}


- (void) drawContentView:(CGRect)r highlighted:(BOOL)highlighted {
    
    CGContextRef context = UIGraphicsGetCurrentContext();
    
    UIColor *backgroundColor;
    
    backgroundColor = highlighted ?
                      UIColorFromRGB(NEWSBLUR_HIGHLIGHT_COLOR) : 
                      [UIColor colorWithRed:0.95 green:0.95 blue:0.95 alpha:1.0];

    [backgroundColor set];
    CGContextFillRect(context, r);
    
    if (highlighted) {
        // top border
        UIColor *blue = UIColorFromRGB(0x6eadf5);
        CGContextSetStrokeColor(context, CGColorGetComponents([blue CGColor]));
        
        CGContextBeginPath(context);
        CGContextMoveToPoint(context, 0, 0.5f);
        CGContextAddLineToPoint(context, r.size.width, 0.5f);
        CGContextStrokePath(context);
        
        // bottom border    
        CGContextBeginPath(context);
        CGContextMoveToPoint(context, 0, r.size.height - .5f);
        CGContextAddLineToPoint(context, r.size.width, r.size.height - .5f);
        CGContextStrokePath(context);
    }
    
    UnreadCountView *unreadCount = [UnreadCountView alloc];
    unreadCount.appDelegate = appDelegate;
    [unreadCount drawInRect:r ps:_positiveCount nt:_neutralCount
                   listType:(isSocial ? NBFeedListSocial : NBFeedListFeed)];
    
    UIColor *textColor = highlighted ? 
                         [UIColor blackColor]:
                         [UIColor blackColor];

    [textColor set];
    UIFont *font;
    if (self.negativeCount || self.neutralCount || self.positiveCount) {
        font = [UIFont fontWithName:@"HelveticaNeue-Bold" size:13.0];
    } else {
        font = [UIFont fontWithName:@"Helvetica" size:12.6];
    }

    if (isSocial) {
        if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
            [self.feedFavicon drawInRect:CGRectMake(9.0, 2.0, 28.0, 28.0)];
            [feedTitle 
             drawInRect:CGRectMake(46, 7, r.size.width - ([unreadCount offsetWidth] + 36) - 10 - 16, 20.0)
             withFont:font
             lineBreakMode:UILineBreakModeTailTruncation 
             alignment:UITextAlignmentLeft]; 
        } else {
            [self.feedFavicon drawInRect:CGRectMake(9.0, 3.0, 26.0, 26.0)];
            [feedTitle 
             drawInRect:CGRectMake(42, 7, r.size.width - ([unreadCount offsetWidth] + 36) - 10 - 12, 20.0)
             withFont:font
             lineBreakMode:UILineBreakModeTailTruncation 
             alignment:UITextAlignmentLeft];
        }

    } else {
        if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
            [self.feedFavicon drawInRect:CGRectMake(12.0, 7.0, 16.0, 16.0)];
            [feedTitle 
             drawInRect:CGRectMake(36.0, 7.0, r.size.width - ([unreadCount offsetWidth] + 36) - 10, 20.0)
             withFont:font
             lineBreakMode:UILineBreakModeTailTruncation 
             alignment:UITextAlignmentLeft];
        } else {
            [self.feedFavicon drawInRect:CGRectMake(9.0, 7.0, 16.0, 16.0)];
            [feedTitle 
             drawInRect:CGRectMake(34.0, 7.0, r.size.width - ([unreadCount offsetWidth] + 36) - 10, 20.0)
             withFont:font
             lineBreakMode:UILineBreakModeTailTruncation 
             alignment:UITextAlignmentLeft];
        }
    }
    
}



@end