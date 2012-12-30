from django.conf.urls.defaults import *
from apps.profile import views

urlpatterns = patterns('',
    url(r'^get_preferences?/?', views.get_preference),
    url(r'^set_preference/?', views.set_preference),
    url(r'^set_account_settings/?', views.set_account_settings),
    url(r'^get_view_setting/?', views.get_view_setting),
    url(r'^set_view_setting/?', views.set_view_setting),
    url(r'^set_collapsed_folders/?', views.set_collapsed_folders),
    url(r'^paypal_form/?', views.paypal_form),
    url(r'^paypal_return/?', views.paypal_return, name='paypal-return'),
    url(r'^is_premium/?', views.profile_is_premium, name='profile-is-premium'),
    url(r'^paypal_ipn/?', include('paypal.standard.ipn.urls'), name='paypal-ipn'),
    url(r'^stripe_form/?', views.stripe_form, name='stripe-form'),
    url(r'^activities/?', views.load_activities, name='profile-activities'),
    url(r'^payment_history/?', views.payment_history, name='profile-payment-history'),
)
