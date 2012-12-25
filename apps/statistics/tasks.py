from celery.task import Task
from apps.statistics.models import MStatistics
from apps.statistics.models import MFeedback
from apps.statistics.models import MAnalyticsPageLoad, MAnalyticsFetcher
from utils import log as logging



class CollectStats(Task):
    name = 'collect-stats'

    def run(self, **kwargs):
        logging.debug(" ---> ~FMCollecting stats...")
        MStatistics.collect_statistics()
        
        
class CollectFeedback(Task):
    name = 'collect-feedback'

    def run(self, **kwargs):
        logging.debug(" ---> ~FMCollecting feedback...")
        MFeedback.collect_feedback()

class CleanAnalytics(Task):
    name = 'clean-analytics'

    def run(self, **kwargs):
        logging.debug(" ---> ~FMCleaning analytics...")
        MAnalyticsFetcher.clean()
        MAnalyticsPageLoad.clean()
        logging.debug(" ---> ~FMDone cleaning analytics...")