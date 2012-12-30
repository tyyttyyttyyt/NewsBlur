import datetime
import threading
import sys
import traceback
import pprint
from django.core.mail import mail_admins
from django.utils.translation import ungettext
from django.conf import settings
from utils import log as logging

class TimeoutError(Exception): pass
def timelimit(timeout):
    """borrowed from web.py"""
    def _1(function):
        def _2(*args, **kw):
            class Dispatch(threading.Thread):
                def __init__(self):
                    threading.Thread.__init__(self)
                    self.result = None
                    self.error = None
                    
                    self.setDaemon(True)
                    self.start()

                def run(self):
                    try:
                        self.result = function(*args, **kw)
                    except:
                        self.error = sys.exc_info()
            c = Dispatch()
            c.join(timeout)
            if c.isAlive():
                raise TimeoutError, 'took too long'
            if c.error:
                tb = ''.join(traceback.format_exception(c.error[0], c.error[1], c.error[2]))
                logging.debug(tb)
                mail_admins('Error in timeout: %s' % c.error[0], tb)
                raise c.error[0], c.error[1], c.error[2]
            return c.result
        return _2
    return _1

         
def utf8encode(tstr):
    """ Encodes a unicode string in utf-8
    """
    if not tstr:
        return u''
    # this is _not_ pretty, but it works
    try:
        return unicode(tstr.encode('utf-8', "xmlcharrefreplace"))
    except UnicodeDecodeError:
        # it's already UTF8.. sigh
        try:
            return unicode(tstr.decode('utf-8').encode('utf-8'))
        except UnicodeDecodeError:
            return u''

# From: http://www.poromenos.org/node/87
def levenshtein_distance(first, second):
    """Find the Levenshtein distance between two strings."""
    if len(first) > len(second):
        first, second = second, first
    if len(second) == 0:
        return len(first)
    first_length = len(first) + 1
    second_length = len(second) + 1
    distance_matrix = [[0] * second_length for x in range(first_length)]
    for i in range(first_length):
       distance_matrix[i][0] = i
    for j in range(second_length):
       distance_matrix[0][j]=j
    for i in xrange(1, first_length):
        for j in range(1, second_length):
            deletion = distance_matrix[i-1][j] + 1
            insertion = distance_matrix[i][j-1] + 1
            substitution = distance_matrix[i-1][j-1]
            if first[i-1] != second[j-1]:
                substitution += 1
            distance_matrix[i][j] = min(insertion, deletion, substitution)
    return distance_matrix[first_length-1][second_length-1]
    
def _do_timesince(d, chunks, now=None):
    """
    Started as a copy of django.util.timesince.timesince, but modified to
    only output one time unit, and use months as the maximum unit of measure.
    
    Takes two datetime objects and returns the time between d and now
    as a nicely formatted string, e.g. "10 minutes".  If d occurs after now,
    then "0 minutes" is returned.

    Units used are months, weeks, days, hours, and minutes.
    Seconds and microseconds are ignored.
    """
    # Convert datetime.date to datetime.datetime for comparison
    if d.__class__ is not datetime.datetime:
        d = datetime.datetime(d.year, d.month, d.day)

    if not now:
        now = datetime.datetime.utcnow()

    # ignore microsecond part of 'd' since we removed it from 'now'
    delta = now - (d - datetime.timedelta(0, 0, d.microsecond))
    since = delta.days * 24 * 60 * 60 + delta.seconds
    if since > 10:
        for i, (seconds, name) in enumerate(chunks):
            count = since // seconds
            if count != 0:
                break
        s = '%(number)d %(type)s' % {'number': count, 'type': name(count)}
    else:
        s = 'just a second'
    return s

def relative_timesince(value):
    if not value:
        return u''

    chunks = (
      (60 * 60 * 24, lambda n: ungettext('day', 'days', n)),
      (60 * 60, lambda n: ungettext('hour', 'hours', n)),
      (60, lambda n: ungettext('minute', 'minutes', n)),
      (1, lambda n: ungettext('second', 'seconds', n)),
      (0, lambda n: 'just now'),
    )
    return _do_timesince(value, chunks)
    
def relative_timeuntil(value):
    if not value:
        return u''

    chunks = (
      (60 * 60, lambda n: ungettext('hour', 'hours', n)),
      (60, lambda n: ungettext('minute', 'minutes', n))
    )
    
    now = datetime.datetime.utcnow()
    
    return _do_timesince(now, chunks, value)

def seconds_timesince(value):
    now = datetime.datetime.utcnow()
    delta = now - value
    
    return delta.days * 24 * 60 * 60 + delta.seconds
    
def format_relative_date(date, future=False):
    if not date or date < datetime.datetime(2010, 1, 1):
        return "Soon"
        
    now = datetime.datetime.utcnow()
    diff = abs(now - date)
    if diff < datetime.timedelta(minutes=60):
        minutes = diff.seconds / 60
        return "%s minute%s %s" % (minutes, 
                                   '' if minutes == 1 else 's', 
                                   '' if future else 'ago')
    elif datetime.timedelta(minutes=60) <= diff < datetime.timedelta(minutes=90):
        return "1 hour %s" % ('' if future else 'ago')
    elif diff < datetime.timedelta(hours=24):
        dec = (diff.seconds / 60 + 15) % 60
        if dec >= 30:
            return "%s.5 hours %s" % ((((diff.seconds / 60) + 15) / 60),
                                      '' if future else 'ago')
        else:
            return "%s hours %s" % ((((diff.seconds / 60) + 15) / 60), 
                                    '' if future else 'ago')
    else:
        days = ((diff.seconds / 60) / 60 / 24)
        return "%s day%s %s" % (days, '' if days == 1 else 's', '' if future else 'ago')
    
def add_object_to_folder(obj, in_folder, folders, parent='', added=False):
    obj_identifier = obj
    if isinstance(obj, dict):
        obj_identifier = obj.keys()[0]
        print obj, obj_identifier, folders

    if (not in_folder and not parent and 
        not isinstance(obj, dict) and 
        obj_identifier not in folders):
        folders.append(obj)
        return folders

    child_folder_names = []
    for item in folders:
        if isinstance(item, dict):
            child_folder_names.append(item.keys()[0])
    if isinstance(obj, dict) and in_folder == parent:
        if obj_identifier not in child_folder_names:
            folders.append(obj)
        return folders
        
    for k, v in enumerate(folders):
        if isinstance(v, dict):
            for f_k, f_v in v.items():
                if f_k == in_folder and obj_identifier not in f_v and not added:
                    f_v.append(obj)
                    added = True
                folders[k][f_k] = add_object_to_folder(obj, in_folder, f_v, f_k, added)
    
    return folders  

def mail_feed_error_to_admin(feed, e, local_vars=None, subject=None):
    # Mail the admins with the error
    if not subject:
        subject = "Feed update error"
    exc_info = sys.exc_info()
    subject = '%s: %s' % (subject, repr(e))
    message = 'Traceback:\n%s\n\Feed:\n%s\nLocals:\n%s' % (
        '\n'.join(traceback.format_exception(*exc_info)),
        pprint.pformat(feed.__dict__),
        pprint.pformat(local_vars)
        )
    # print message
    mail_admins(subject, message)