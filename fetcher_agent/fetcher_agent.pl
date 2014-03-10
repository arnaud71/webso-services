#!/usr/bin/perl
#####################################################################
#
#  fetcher agent
#  a standalone  fetcher
#
# input :
#   - url_to_fetch
#   - fetch_id (md5 of the url_to_fetch)
#   - fetcher_url (url of the original fetcher)
#   - user_agent (if null random)
#   - synchro (synchro or assynchronous communication)
#
# output :
#
#   if synchro
#       - content
#       - code
#       - error
#
#  @TODO:
#       - add asynchronous mode
#
#
#  example: http://localhost/cgi-bin/webso-services/fetcher_agent/fetcher_agent.pl?url=http://bitem.hesge.ch
#
####################################################################


#
#
#

use strict;
use CGI::Carp qw(fatalsToBrowser);

use LWP::UserAgent;
use Digest::MD5 qw(md5 md5_hex md5_base64);
use WWW::UserAgent::Random;
use Config::Simple;
use CGI;
use Log::Log4perl qw(:easy);
use JSON;
use Crypt::SSLeay;
use HTTP::Cookies;

########### init log file


#mkdir '/tmp/webso';
my $cfg = new Config::Simple('../webso.cfg');


my $logconf = "
    log4perl.logger.crawler                         = TRACE, crawlerAppender
    log4perl.appender.crawlerAppender               = Log::Log4perl::Appender::File
    log4perl.appender.crawlerAppender.filename      = ".$cfg->param('log_dir')."fetcher_agent.log
    log4perl.appender.crawlerAppender.layout        = PatternLayout
    log4perl.appender.crawlerAppender.layout.ConversionPattern=%d - %m{chomp}%n

";
Log::Log4perl::init(\$logconf);

######### get config


my $webso_services  = $cfg->param('webso_services');
my $USE_PROXY       = $cfg->param('use_proxy');
my $PROXY           = $cfg->param('proxy');

my $RANDOM_AGENT    = $cfg->param('random_agent');          # activate simulation of a random browser name (better)
my $RANDOM_SLEEP    = $cfg->param('random_sleep');          # active sleep during a random period of time between 2 crawl of the same site
my $MIN_TIME_SLEEP  = $cfg->param('min_time_sleep');        # min sleep time between 2 crawl of the same site
my $MAX_TIME_SLEEP  = $cfg->param('max_time_sleep');        # max sleep time between 2 crawl of the same site


# prepare the JSON msg
my $json            = JSON->new->allow_nonref;
my $callback        = q{};
my %perl_response   = ();

########### get params
my $q       = CGI->new;
my $url = q{};


if ($q->param('url')) {
    $url        = $q->param('url');
}
if ($q->param('callback')) {
    $callback   = $q->param('callback');
}

#$url = 'http://www.latimes.com/business/technology/la-fi-tn-woman-attacked-says-she-wont-stop-wearing-google-glass-20140225,0,1735801.story?track=rss';
#$url = 'http://www.hon.ch';

###################

my $ua = LWP::UserAgent->new;
if ($RANDOM_AGENT) {
    $ua->agent(rand_ua("browsers"));
}
$ua->timeout(30);
if ($USE_PROXY) {
    $ua->proxy(['http'], $PROXY);
    $ENV{HTTPS_PROXY} = 'proxyem.etat-ge.ch:80';
    $ENV{PERL_LWP_SSL_VERIFY_HOSTNAME} = 0;
    $ENV{"HTTPS_PROXY_USERNAME"} = 'zzrodin';
    $ENV{"HTTPS_PROXY_PASSWORD"} = 'as789HGI1';
}

my $response = my_get($ua, $url);

if (($response->is_success) || ($response->is_redirect)) {
    $perl_response{'content'}   = $response->decoded_content;
    $perl_response{'code'}      = $response->code;
    $perl_response{'error'}     = 'none';
    get_logger("crawler")->trace("OK: $url");
}
else {
    $perl_response{'error'} = "error fetching $url";
    $perl_response{'code'} = $response->code;
    get_logger("crawler")->trace("ERROR: code:".$response->code." $url");
}


my $json_response   = $json->pretty->encode(\%perl_response);

if ($callback) {
    print 'Access-Control-Allow-Origin: *';
    print 'Access-Control-Allow-Methods: GET';
    print "Content-type: application/javascript\n\n";
    $json_response   = $callback.'('.$json_response.');';
} else {
    # Header for access via browser, curl, etc.
    print "Content-type: application/json\n\n";
}

print $json_response;





#######################################
#### user agent which try several get
######################################
sub my_get {
    my ($ua, $url_page)= @_;
    my $cookies=new HTTP::Cookies(file=>'./cookies.dat',autosave=>1);
    $ua->cookie_jar($cookies);
    my $res = $ua->get($url_page);

    my $count = 5;
    while ($res->code==500) {
        my $sleep_time = int(rand($MAX_TIME_SLEEP-$MIN_TIME_SLEEP))+$MIN_TIME_SLEEP;
        sleep($sleep_time);
        get_logger("crawler")->trace("ERROR: wait $url_page");
        if ($count--<1) {
            last;
        }
        $res = $ua->get($url_page);
    }

    return $res;
}

