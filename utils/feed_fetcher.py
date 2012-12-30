import time
import datetime
import traceback
import multiprocessing
import urllib2
import xml.sax
import redis
import random
import pymongo
from django.conf import settings
from django.db import IntegrityError
from apps.reader.models import UserSubscription
from apps.rss_feeds.models import Feed, MStory
from apps.rss_feeds.page_importer import PageImporter
from apps.rss_feeds.icon_importer import IconImporter
from apps.push.models import PushSubscription
from apps.statistics.models import MAnalyticsFetcher
from utils import feedparser
from utils.story_functions import pre_process_story
from utils import log as logging
from utils.feed_functions import timelimit, TimeoutError, mail_feed_error_to_admin, utf8encode


# Refresh feed code adapted from Feedjack.
# http://feedjack.googlecode.com

FEED_OK, FEED_SAME, FEED_ERRPARSE, FEED_ERRHTTP, FEED_ERREXC = range(5)

def mtime(ttime):
    """ datetime auxiliar function.
    """
    return datetime.datetime.fromtimestamp(time.mktime(ttime))
    
    
class FetchFeed:
    def __init__(self, feed_id, options):
        self.feed = Feed.get_by_id(feed_id)
        self.options = options
        self.fpf = None
    
    @timelimit(20)
    def fetch(self):
        """ 
        Uses feedparser to download the feed. Will be parsed later.
        """
        start = time.time()
        identity = self.get_identity()
        log_msg = u'%2s ---> [%-30s] ~FYFetching feed (~FB%d~FY), last update: %s' % (identity,
                                                            self.feed.title[:30],
                                                            self.feed.id,
                                                            datetime.datetime.now() - self.feed.last_update)
        logging.debug(log_msg)
                                                 
        etag=self.feed.etag
        modified = self.feed.last_modified.utctimetuple()[:7] if self.feed.last_modified else None
        
        if self.options.get('force') or not self.feed.fetched_once or not self.feed.known_good:
            modified = None
            etag = None

        USER_AGENT = 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_7_3) AppleWebKit/536.2.3 (KHTML, like Gecko) Version/5.2 (NewsBlur Feed Fetcher - %s subscriber%s - %s)' % (
            self.feed.num_subscribers,
            's' if self.feed.num_subscribers != 1 else '',
            settings.NEWSBLUR_URL
        )
        if self.options.get('feed_xml'):
            logging.debug(u'   ---> [%-30s] ~FM~BKFeed has been fat pinged. Ignoring fat: %s' % (
                          self.feed.title[:30], len(self.options.get('feed_xml'))))
        
        if self.options.get('fpf'):
            self.fpf = self.options.get('fpf')
            logging.debug(u'   ---> [%-30s] ~FM~BKFeed fetched in real-time with fat ping.' % (
                          self.feed.title[:30]))
            return FEED_OK, self.fpf

        try:
            self.fpf = feedparser.parse(self.feed.feed_address,
                                        agent=USER_AGENT,
                                        etag=etag,
                                        modified=modified)
        except (TypeError, ValueError), e:
            logging.debug(u'   ***> [%-30s] ~FR%s, turning off microformats.' % 
                          (self.feed.title[:30], e))
            feedparser.PARSE_MICROFORMATS = False
            self.fpf = feedparser.parse(self.feed.feed_address,
                                        agent=USER_AGENT,
                                        etag=etag,
                                        modified=modified)
            feedparser.PARSE_MICROFORMATS = True
            
        logging.debug(u'   ---> [%-30s] ~FYFeed fetch in ~FM%.4ss' % (
                      self.feed.title[:30], time.time() - start))

        return FEED_OK, self.fpf
        
    def get_identity(self):
        identity = "X"

        current_process = multiprocessing.current_process()
        if current_process._identity:
            identity = current_process._identity[0]

        return identity
        
class ProcessFeed:
    def __init__(self, feed_id, fpf, options):
        self.feed_id = feed_id
        self.options = options
        self.fpf = fpf
    
    def refresh_feed(self):
        self.feed = Feed.get_by_id(self.feed_id)
        if self.feed_id != self.feed.pk:
            logging.debug(" ***> Feed has changed: from %s to %s" % (self.feed_id, self.feed.pk))
            self.feed_id = self.feed.pk
        
    def process(self):
        """ Downloads and parses a feed.
        """
        start = time.time()
        self.refresh_feed()
        
        ret_values = dict(new=0, updated=0, same=0, error=0)

        # logging.debug(u' ---> [%d] Processing %s' % (self.feed.id, self.feed.feed_title))

        if hasattr(self.fpf, 'status'):
            if self.options['verbose']:
                if self.fpf.bozo and self.fpf.status != 304:
                    logging.debug(u'   ---> [%-30s] ~FRBOZO exception: %s ~SB(%s entries)' % (
                                  self.feed.title[:30],
                                  self.fpf.bozo_exception,
                                  len(self.fpf.entries)))
                    
            if self.fpf.status == 304:
                self.feed = self.feed.save()
                self.feed.save_feed_history(304, "Not modified")
                return FEED_SAME, ret_values
            
            if self.fpf.status in (302, 301):
                if not self.fpf.href.endswith('feedburner.com/atom.xml'):
                    self.feed.feed_address = self.fpf.href
                if not self.feed.known_good:
                    self.feed.fetched_once = True
                    logging.debug("   ---> [%-30s] ~SB~SK~FRFeed is %s'ing. Refetching..." % (self.feed.title[:30], self.fpf.status))
                    self.feed = self.feed.schedule_feed_fetch_immediately()
                if not self.fpf.entries:
                    self.feed = self.feed.save()
                    self.feed.save_feed_history(self.fpf.status, "HTTP Redirect")
                    return FEED_ERRHTTP, ret_values
            if self.fpf.status >= 400:
                logging.debug("   ---> [%-30s] ~SB~FRHTTP Status code: %s. Checking address..." % (self.feed.title[:30], self.fpf.status))
                fixed_feed = None
                if not self.feed.known_good:
                    fixed_feed = self.feed.check_feed_link_for_feed_address()
                if not fixed_feed:
                    self.feed.save_feed_history(self.fpf.status, "HTTP Error")
                self.feed = self.feed.save()
                return FEED_ERRHTTP, ret_values

        if not self.fpf.entries:
            if self.fpf.bozo and isinstance(self.fpf.bozo_exception, feedparser.NonXMLContentType):
                logging.debug("   ---> [%-30s] ~SB~FRFeed is Non-XML. %s entries. Checking address..." % (self.feed.title[:30], len(self.fpf.entries)))
                fixed_feed = None
                if not self.feed.known_good:
                    fixed_feed = self.feed.check_feed_link_for_feed_address()
                if not fixed_feed:
                    self.feed.save_feed_history(552, 'Non-xml feed', self.fpf.bozo_exception)
                self.feed = self.feed.save()
                return FEED_ERRPARSE, ret_values
            elif self.fpf.bozo and isinstance(self.fpf.bozo_exception, xml.sax._exceptions.SAXException):
                logging.debug("   ---> [%-30s] ~SB~FRFeed has SAX/XML parsing issues. %s entries. Checking address..." % (self.feed.title[:30], len(self.fpf.entries)))
                fixed_feed = None
                if not self.feed.known_good:
                    fixed_feed = self.feed.check_feed_link_for_feed_address()
                if not fixed_feed:
                    self.feed.save_feed_history(553, 'SAX Exception', self.fpf.bozo_exception)
                self.feed = self.feed.save()
                return FEED_ERRPARSE, ret_values
                
        # the feed has changed (or it is the first time we parse it)
        # saving the etag and last_modified fields
        self.feed.etag = self.fpf.get('etag')
        if self.feed.etag:
            self.feed.etag = self.feed.etag[:255]
        # some times this is None (it never should) *sigh*
        if self.feed.etag is None:
            self.feed.etag = ''

        try:
            self.feed.last_modified = mtime(self.fpf.modified)
        except:
            pass
        
        self.fpf.entries = self.fpf.entries[:50]
        
        if self.fpf.feed.get('title'):
            self.feed.feed_title = self.fpf.feed.get('title')
        tagline = self.fpf.feed.get('tagline', self.feed.data.feed_tagline)
        if tagline:
            self.feed.data.feed_tagline = utf8encode(tagline)
            self.feed.data.save()
        if not self.feed.feed_link_locked:
            self.feed.feed_link = self.fpf.feed.get('link') or self.fpf.feed.get('id') or self.feed.feed_link
        
<<<<<<< HEAD
        self.feed = self.feed.save()
=======
        guids = []
        for entry in self.fpf.entries:
            if entry.get('id', ''):
                guids.append(entry.get('id', ''))
            elif entry.get('link'):
                guids.append(entry.link)
            elif entry.get('title'):
                guids.append(entry.title)

<<<<<<< HEAD
        self.feed.save()
        self.refresh_feed()
>>>>>>> Refreshing feed on fetch.
=======
        self.feed = self.feed.save()
>>>>>>> Fixing errors in timeouts to show the correct error. Also fixing microformats parsing issue and allow IPv6 URLs in enclosures to be ignored, fixing a bunch of feeds.

        # Compare new stories to existing stories, adding and updating
        start_date = datetime.datetime.utcnow()
        story_guids = []
        stories = []
        for entry in self.fpf.entries:
            story = pre_process_story(entry)
            if story.get('published') < start_date:
                start_date = story.get('published')
            stories.append(story)
            story_guids.append(story.get('guid') or story.get('link'))

        existing_stories = list(MStory.objects(
            # story_guid__in=story_guids,
            story_date__gte=start_date,
            story_feed_id=self.feed.pk
        ).limit(max(int(len(story_guids)*1.5), 10)))
        
        ret_values = self.feed.add_update_stories(stories, existing_stories,
                                                  verbose=self.options['verbose'])

        if ((not self.feed.is_push or self.options.get('force'))
            and hasattr(self.fpf, 'feed') and 
            hasattr(self.fpf.feed, 'links') and self.fpf.feed.links):
            hub_url = None
            self_url = self.feed.feed_address
            for link in self.fpf.feed.links:
                if link['rel'] == 'hub':
                    hub_url = link['href']
                elif link['rel'] == 'self':
                    self_url = link['href']
            if hub_url and self_url and not settings.DEBUG:
                logging.debug(u'   ---> [%-30s] ~BB~FWSubscribing to PuSH hub: %s' % (
                              self.feed.title[:30], hub_url))
                PushSubscription.objects.subscribe(self_url, feed=self.feed, hub=hub_url)
        
        logging.debug(u'   ---> [%-30s] ~FYParsed Feed: %snew=%s~SN~FY %sup=%s~SN same=%s%s~SN %serr=%s~SN~FY total=~SB%s' % (
                      self.feed.title[:30], 
                      '~FG~SB' if ret_values['new'] else '', ret_values['new'],
                      '~FY~SB' if ret_values['updated'] else '', ret_values['updated'],
                      '~SB' if ret_values['same'] else '', ret_values['same'],
                      '~FR~SB' if ret_values['error'] else '', ret_values['error'],
                      len(self.fpf.entries)))
        self.feed.update_all_statistics(full=bool(ret_values['new']), force=self.options['force'])
        self.feed.trim_feed()
        self.feed.save_feed_history(200, "OK")
        
        if self.options['verbose']:
            logging.debug(u'   ---> [%-30s] ~FBTIME: feed parse in ~FM%.4ss' % (
                          self.feed.title[:30], time.time() - start))
        
        return FEED_OK, ret_values

        
class Dispatcher:
    def __init__(self, options, num_threads):
        self.options = options
        self.feed_stats = {
            FEED_OK:0,
            FEED_SAME:0,
            FEED_ERRPARSE:0,
            FEED_ERRHTTP:0,
            FEED_ERREXC:0}
        self.feed_trans = {
            FEED_OK:'ok',
            FEED_SAME:'unchanged',
            FEED_ERRPARSE:'cant_parse',
            FEED_ERRHTTP:'http_error',
            FEED_ERREXC:'exception'}
        self.feed_keys = sorted(self.feed_trans.keys())
        self.num_threads = num_threads
        self.time_start = datetime.datetime.utcnow()
        self.workers = []

    def refresh_feed(self, feed_id):
        """Update feed, since it may have changed"""
        return Feed.objects.using('default').get(pk=feed_id)
        
    def process_feed_wrapper(self, feed_queue):
        delta = None
        current_process = multiprocessing.current_process()
        identity = "X"
        feed = None
        
        if current_process._identity:
            identity = current_process._identity[0]
            
        for feed_id in feed_queue:
<<<<<<< HEAD
            start_duration = time.time()
            feed_fetch_duration = None
            feed_process_duration = None
            page_duration = None
            icon_duration = None
            feed_code = None
        
            ret_entries = {
                ENTRY_NEW: 0,
                ENTRY_UPDATED: 0,
                ENTRY_SAME: 0,
                ENTRY_ERR: 0
            }
=======
>>>>>>> First half of DynamoDB trial, converting stories from mongo to dynamodb. Still needs to be updated/inserted on feed update, and then processed with all MStory uses.
            start_time = time.time()
            ret_feed = FEED_ERREXC
            try:
                feed = self.refresh_feed(feed_id)
                
                skip = False
                if self.options.get('fake'):
                    skip = True
                    weight = "-"
                    quick = "-"
                    rand = "-"
                elif (self.options.get('quick') and not self.options['force'] and 
                      feed.known_good and feed.fetched_once and not feed.is_push):
                    weight = feed.stories_last_month * feed.num_subscribers
                    random_weight = random.randint(1, max(weight, 1))
                    quick = float(self.options.get('quick', 0))
                    rand = random.random()
                    if random_weight < 100 and rand < quick:
                        skip = True
                if skip:
                    logging.debug('   ---> [%-30s] ~BGFaking fetch, skipping (%s/month, %s subs, %s < %s)...' % (
                        feed.title[:30],
                        weight,
                        feed.num_subscribers,
                        rand, quick))
                    continue
                    
                ffeed = FetchFeed(feed_id, self.options)
                ret_feed, fetched_feed = ffeed.fetch()
                feed_fetch_duration = time.time() - start_duration
                
                if ((fetched_feed and ret_feed == FEED_OK) or self.options['force']):
                    pfeed = ProcessFeed(feed_id, fetched_feed, self.options)
                    ret_feed, ret_entries = pfeed.process()
                    feed = pfeed.feed
                    feed_process_duration = time.time() - start_duration
                    
                    if ret_entries['new'] or self.options['force']:
                        start = time.time()
                        if not feed.known_good or not feed.fetched_once:
                            feed.known_good = True
                            feed.fetched_once = True
                            feed = feed.save()
                        # MUserStory.delete_old_stories(feed_id=feed.pk)
                        if random.random() <= 0.01:
                            feed.sync_redis()
                        try:
                            self.count_unreads_for_subscribers(feed)
                        except TimeoutError:
                            logging.debug('   ---> [%-30s] Unread count took too long...' % (feed.title[:30],))
                        if self.options['verbose']:
                            logging.debug(u'   ---> [%-30s] ~FBTIME: unread count in ~FM%.4ss' % (
                                          feed.title[:30], time.time() - start))
<<<<<<< HEAD
                    cache.delete('feed_stories:%s-%s-%s' % (feed.id, 0, 25))
                    # if ret_entries['new'] or ret_entries['updated'] or self.options['force']:
=======
                    # if ret_entries.get(ENTRY_NEW) or ret_entries.get(ENTRY_UPDATED) or self.options['force']:
>>>>>>> Cleaning up RSS feed header for shared stories feeds.
                    #     feed.get_stories(force=True)
            except KeyboardInterrupt:
                break
            except urllib2.HTTPError, e:
                logging.debug('   ---> [%-30s] ~FRFeed throws HTTP error: ~SB%s' % (unicode(feed_id)[:30], e.fp.read()))
                feed.save_feed_history(e.code, e.msg, e.fp.read())
                fetched_feed = None
            except Feed.DoesNotExist, e:
                logging.debug('   ---> [%-30s] ~FRFeed is now gone...' % (unicode(feed_id)[:30]))
                continue
            except TimeoutError, e:
                logging.debug('   ---> [%-30s] ~FRFeed fetch timed out...' % (feed.title[:30]))
                feed.save_feed_history(505, 'Timeout', '')
                feed_code = 505
                fetched_feed = None
            except Exception, e:
                logging.debug('[%d] ! -------------------------' % (feed_id,))
                tb = traceback.format_exc()
                logging.error(tb)
                logging.debug('[%d] ! -------------------------' % (feed_id,))
                ret_feed = FEED_ERREXC 
                feed = Feed.get_by_id(getattr(feed, 'pk', feed_id))
                feed.save_feed_history(500, "Error", tb)
                feed_code = 500
                fetched_feed = None
                mail_feed_error_to_admin(feed, e, local_vars=locals())
                if (not settings.DEBUG and hasattr(settings, 'RAVEN_CLIENT') and
                    settings.RAVEN_CLIENT):
                    settings.RAVEN_CLIENT.captureException(e)

            if not feed_code:
                if ret_feed == FEED_OK:
                    feed_code = 200
                elif ret_feed == FEED_SAME:
                    feed_code = 304
                elif ret_feed == FEED_ERRHTTP:
                    feed_code = 400
                if ret_feed == FEED_ERREXC:
                    feed_code = 500
                elif ret_feed == FEED_ERRPARSE:
                    feed_code = 550
                elif ret_feed == FEED_ERRPARSE:
                    feed_code = 550
                
            feed = self.refresh_feed(feed.pk)
            if ((self.options['force']) or 
                (random.random() > .9) or
                (fetched_feed and
                 feed.feed_link and
                 feed.has_page and
                 (ret_feed == FEED_OK or
                  (ret_feed == FEED_SAME and feed.stories_last_month > 10)))):
                  
                logging.debug(u'   ---> [%-30s] ~FYFetching page: %s' % (feed.title[:30], feed.feed_link))
                page_importer = PageImporter(feed)
                try:
                    page_data = page_importer.fetch_page()
                    page_duration = time.time() - start_duration
                except TimeoutError, e:
                    logging.debug('   ---> [%-30s] ~FRPage fetch timed out...' % (feed.title[:30]))
                    page_data = None
                    feed.save_page_history(555, 'Timeout', '')
                except Exception, e:
                    logging.debug('[%d] ! -------------------------' % (feed_id,))
                    tb = traceback.format_exc()
                    logging.error(tb)
                    logging.debug('[%d] ! -------------------------' % (feed_id,))
                    feed.save_page_history(550, "Page Error", tb)
                    fetched_feed = None
                    page_data = None
                    mail_feed_error_to_admin(feed, e, local_vars=locals())
                    settings.RAVEN_CLIENT.captureException(e)

                feed = self.refresh_feed(feed.pk)
                logging.debug(u'   ---> [%-30s] ~FYFetching icon: %s' % (feed.title[:30], feed.feed_link))
                icon_importer = IconImporter(feed, page_data=page_data, force=self.options['force'])
                try:
                    icon_importer.save()
                    icon_duration = time.time() - start_duration
                except TimeoutError, e:
                    logging.debug('   ---> [%-30s] ~FRIcon fetch timed out...' % (feed.title[:30]))
                    feed.save_page_history(556, 'Timeout', '')
                except Exception, e:
                    logging.debug('[%d] ! -------------------------' % (feed_id,))
                    tb = traceback.format_exc()
                    logging.error(tb)
                    logging.debug('[%d] ! -------------------------' % (feed_id,))
                    # feed.save_feed_history(560, "Icon Error", tb)
                    mail_feed_error_to_admin(feed, e, local_vars=locals())
                    settings.RAVEN_CLIENT.captureException(e)
            else:
                logging.debug(u'   ---> [%-30s] ~FBSkipping page fetch: (%s on %s stories) %s' % (feed.title[:30], self.feed_trans[ret_feed], feed.stories_last_month, '' if feed.has_page else ' [HAS NO PAGE]'))
            
            feed = self.refresh_feed(feed.pk)
            delta = time.time() - start_time
            
            feed.last_load_time = round(delta)
            feed.fetched_once = True
            try:
                feed = feed.save()
            except IntegrityError:
                logging.debug("   ---> [%-30s] ~FRIntegrityError on feed: %s" % (feed.title[:30], feed.feed_address,))
            
            if ret_entries['new']:
                self.publish_to_subscribers(feed)
                
            done_msg = (u'%2s ---> [%-30s] ~FYProcessed in ~FM~SB%.4ss~FY~SN (~FB%s~FY) [%s]' % (
                identity, feed.feed_title[:30], delta,
                feed.pk, self.feed_trans[ret_feed],))
            logging.debug(done_msg)
            total_duration = time.time() - start_duration
            MAnalyticsFetcher.add(feed_id=feed.pk, feed_fetch=feed_fetch_duration,
                                  feed_process=feed_process_duration, 
                                  page=page_duration, icon=icon_duration,
                                  total=total_duration, feed_code=feed_code)
            
            self.feed_stats[ret_feed] += 1
                
        if len(feed_queue) == 1:
            return feed
        
        # time_taken = datetime.datetime.utcnow() - self.time_start
    
    def publish_to_subscribers(self, feed):
        try:
            r = redis.Redis(connection_pool=settings.REDIS_POOL)
            listeners_count = r.publish(str(feed.pk), 'story:new')
            if listeners_count:
                logging.debug("   ---> [%-30s] ~FMPublished to %s subscribers" % (feed.title[:30], listeners_count))
        except redis.ConnectionError:
            logging.debug("   ***> [%-30s] ~BMRedis is unavailable for real-time." % (feed.title[:30],))
        
    def count_unreads_for_subscribers(self, feed):
        UNREAD_CUTOFF = datetime.datetime.utcnow() - datetime.timedelta(days=settings.DAYS_OF_UNREAD)
        user_subs = UserSubscription.objects.filter(feed=feed, 
                                                    active=True,
                                                    user__profile__last_seen_on__gte=UNREAD_CUTOFF)\
                                            .order_by('-last_read_date')
        
        if not user_subs.count():
            return
            
        for sub in user_subs:
            if not sub.needs_unread_recalc:
                sub.needs_unread_recalc = True
                sub.save()

        if self.options['compute_scores']:
            stories = MStory.objects(story_feed_id=feed.pk,
                                     story_date__gte=UNREAD_CUTOFF)\
                            .read_preference(pymongo.ReadPreference.PRIMARY)
            stories = Feed.format_stories(stories, feed.pk)
            logging.debug(u'   ---> [%-30s] ~FYComputing scores: ~SB%s stories~SN with ~SB%s subscribers ~SN(%s/%s/%s)' % (
                          feed.title[:30], len(stories), user_subs.count(),
                          feed.num_subscribers, feed.active_subscribers, feed.premium_subscribers))        
            self.calculate_feed_scores_with_stories(user_subs, stories)
        elif self.options.get('mongodb_replication_lag'):
            logging.debug(u'   ---> [%-30s] ~BR~FYSkipping computing scores: ~SB%s seconds~SN of mongodb lag' % (
              feed.title[:30], self.options.get('mongodb_replication_lag')))
    
    @timelimit(10)
    def calculate_feed_scores_with_stories(self, user_subs, stories):
        for sub in user_subs:
            silent = False if self.options['verbose'] >= 2 else True
            sub.calculate_feed_scores(silent=silent, stories=stories)
            
    def add_jobs(self, feeds_queue, feeds_count=1):
        """ adds a feed processing job to the pool
        """
        self.feeds_queue = feeds_queue
        self.feeds_count = feeds_count
            
    def run_jobs(self):
        if self.options['single_threaded']:
            return self.process_feed_wrapper(self.feeds_queue[0])
        else:
            for i in range(self.num_threads):
                feed_queue = self.feeds_queue[i]
                self.workers.append(multiprocessing.Process(target=self.process_feed_wrapper,
                                                            args=(feed_queue,)))
            for i in range(self.num_threads):
                self.workers[i].start()

                