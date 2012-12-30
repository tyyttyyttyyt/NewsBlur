NEWSBLUR.Views.SocialPage = Backbone.View.extend({
    
    el: 'body',
    
    page: 1,

    auto_advance_pages: 0,
    
    MAX_AUTO_ADVANCED_PAGES: 15,
        
    events: {
        "click .NB-page-controls-next:not(.NB-loaded):not(.NB-loading)" : "next_page",
        "click .NB-follow-user" : "follow_user"
    },
    
    stories: {},
    
    next_animation_options: {
        'duration': 500,
        'easing': 'easeInOutQuint',
        'queue': false
    },
    
    initialize: function() {
        NEWSBLUR.assets = new NEWSBLUR.SocialPageAssets();
        NEWSBLUR.router = new NEWSBLUR.Router;
        Backbone.history.start({pushState: true});
        
        this.initialize_stories();
    },
    
    initialize_stories: function($stories) {
        var self = this;
        $stories = $stories || this.$el;
        
        $('.NB-story', $stories).each(function() {
            var $story = $(this);
            var guid = $story.data('guid');
            if (!self.stories[guid]) {
                var story_view = new NEWSBLUR.Views.SocialPageStory({el: $(this)});
                self.stories[story_view.story_guid] = story_view;
            }
        });
        
        this.find_story();
    },
    
    find_story: function() {
        var search_story_guid = NEWSBLUR.router.story_guid;
        if (search_story_guid && this.auto_advance_pages < this.MAX_AUTO_ADVANCED_PAGES) {
            var found_guid = _.detect(_.keys(this.stories), function(guid) {
                return guid.indexOf(search_story_guid) == 0;
            });
            if (found_guid) {
                var story_view = this.stories[found_guid];
                _.delay(_.bind(this.scroll_to_story, this, story_view, 1), 0);
                _.delay(_.bind(this.scroll_to_story, this, story_view, 3), 800);
                NEWSBLUR.router.story_guid = null;
            } else {
                this.auto_advance_pages += 1;
                this.next_page();
            }
        }
    },
    
    scroll_to_story: function(story_view, run) {
        $('body').scrollTo(story_view.$mark, {
            offset: -32,
            duration: run == 1 ? 1000 : 500,
            easing: run == 1 ? 'easeInQuint' : 'easeOutQuint',
            queue: false
        });
    },
    
    // ==========
    // = Events =
    // ==========
    
    next_page: function(e) {
        if ($('.NB-page-controls-end').length) return;
        
        var $button = e && $(e.currentTarget) || $('.NB-page-controls-next').last();
        var $next = $('.NB-page-controls-text-next', $button);
        var $loading = $('.NB-page-controls-text-loading', $button);
        var $loaded = $('.NB-page-controls-text-loaded', $button);
        var height = this.$('.NB-page-controls').height();
        var innerheight = $button.height();
        
        $loaded.animate({'bottom': height}, this.next_animation_options);
        $loading.text('Loading...').css('bottom', height).animate({'bottom': innerheight}, this.next_animation_options);
        $next.animate({'bottom': -1 * innerheight}, this.next_animation_options);
        $button.addClass('NB-loading');
        
        $button.animate({'backgroundColor': '#5C89C9'}, 650)
               .animate({'backgroundColor': '#2B478C'}, 900);
        this.feed_stories_loading = setInterval(function() {
            $button.animate({'backgroundColor': '#5C89C9'}, {'duration': 650})
                   .animate({'backgroundColor': '#2B478C'}, 900);
        }, 1550);
        
        this.page += 1;
        
        $.ajax({
            url: '/',
            method: 'GET',
            data: {
                'page': this.page,
                'format': 'html',
                'feed_id': NEWSBLUR.router.feed_id
            },
            success: _.bind(this.post_next_page, this),
            error: _.bind(this.error_next_page, this)
        });
    },
    
    post_next_page: function(data) {
        var $controls = this.$('.NB-page-controls').last();
        var $button = $('.NB-page-controls-next', $controls);
        var $loading = $('.NB-page-controls-text-loading', $controls);
        var $loaded = $('.NB-page-controls-text-loaded', $controls);
        var height = $controls.height();
        var innerheight = $button.height();
        
        $button.removeClass('NB-loading').addClass('NB-loaded');
        $button.stop(true).animate({'backgroundColor': '#86B86B'}, {'duration': 750, 'easing': 'easeOutExpo', 'queue': false});
        
        $loaded.text('Page ' + this.page).css('bottom', height).animate({'bottom': innerheight}, this.next_animation_options);
        $loading.animate({'bottom': -1 * innerheight}, this.next_animation_options);
        
        clearInterval(this.feed_stories_loading);
        
        var $stories = $(data);
        $controls.after($stories);
        this.initialize_stories();
    },
    
    error_next_page: function() {
        var $controls = this.$('.NB-page-controls').last();
        var $button = $('.NB-page-controls-next', $controls);
        var $loading = $('.NB-page-controls-text-loading', $controls);
        var $next = $('.NB-page-controls-text-next', $controls);
        var height = $controls.height();
        var innerheight = $button.height();
        
        $button.removeClass('NB-loading').removeClass('NB-loaded');
        $button.stop(true).animate({'backgroundColor': '#B6686B'}, {
            'duration': 750, 
            'easing': 'easeOutExpo', 
            'queue': false
        });
        
        this.page -= 1;
        
        $next.text('Whoops! Something went wrong. Try again.')
             .animate({'bottom': innerheight}, this.next_animation_options);
        $loading.animate({'bottom': height}, this.next_animation_options);
        
        clearInterval(this.feed_stories_loading);
    },
    
    follow_user: function() {
        this.$(".NB-follow-user").html('Following...');
        NEWSBLUR.assets.follow_user(NEWSBLUR.Globals.blurblog_user_id, _.bind(function(data) {
            var message = 'You are now following ' + NEWSBLUR.Globals.blurblog_username;
            if (data.follow_profile.requested_follow) {
                message = 'Your request to follow ' + NEWSBLUR.Globals.blurblog_username + ' has been sent';
            }
            this.$(".NB-follow-user").replaceWith(message);
        }, this));
    }
    
});

$(document).ready(function() {

    NEWSBLUR.app.social_page = new NEWSBLUR.Views.SocialPage();

});
