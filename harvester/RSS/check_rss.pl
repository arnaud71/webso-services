#!/usr/bin/perl
#####################################################################
#
#  rss checker
# check if rss is available, links are read
#
# input:
#   - rss url
#
# output (json):
#   - links : list of urls
#   - count : number of links
#   - code : http code
#   - error : error message
#
# exemple : http://localhost/cgi-bin/webso-services/harvester/RSS/check_rss.pl?url=http://feeds.feedburner.com/bitem/news
####################################################################

use strict;
use CGI::Carp qw(fatalsToBrowser);
use LWP::UserAgent;
use XML::FeedPP;
use WWW::UserAgent::Random;
use DateTime::Format::RSS;
use Time::localtime;
use Log::Log4perl qw(:easy);
use Config::Simple;
use JSON;
use HTML::Restrict;
use HTML::Entities;
use CGI;

#### init

my $cfg = new Config::Simple('../../webso.cfg');

my $q               = CGI->new;
# prepare the JSON msg
my $json            = JSON->new->allow_nonref;
my $callback        = q{};
my %perl_response   = ();


################ CRAWLER CONST ###########

my $webso_services  = $cfg->param('webso_services');
my $USE_PROXY       = $cfg->param('use_proxy');
my $PROXY           = $cfg->param('proxy');

my $RANDOM_AGENT    = $cfg->param('random_agent');          # activate simulation of a random browser name (better)
my $RANDOM_SLEEP    = $cfg->param('random_sleep');          # active sleep during a random period of time between 2 crawl of the same site
my $MIN_TIME_SLEEP  = $cfg->param('min_time_sleep');        # min sleep time between 2 crawl of the same site
my $MAX_TIME_SLEEP  = $cfg->param('max_time_sleep');        # max sleep time between 2 crawl of the same site


# get params

my $url             = $ARGV[0]; #required


###### end of CONST


my $logconf = "
    log4perl.logger.crawler                         = TRACE, crawlerAppender
    log4perl.appender.crawlerAppender               = Log::Log4perl::Appender::File
    log4perl.appender.crawlerAppender.filename      = ".$cfg->param('log_dir')."rss_checker.log
    log4perl.appender.crawlerAppender.layout        = PatternLayout
    log4perl.appender.crawlerAppender.layout.ConversionPattern=%d - %m{chomp}%n

";

Log::Log4perl::init(\$logconf);


# get params

if ($q->param('url')) {
    $url     = $q->param('url');
}


if ($q->param('callback')) {
    $callback    = $q->param('callback');
}



my $ua = LWP::UserAgent->new;
if ($RANDOM_AGENT) {
    $ua->agent(rand_ua("browsers"));
}
$ua->timeout(30);
#$ua->env_proxy;
if ($USE_PROXY) {
    $ua->proxy(['http'], $PROXY);
    $ENV{HTTPS_PROXY} = 'proxyem.etat-ge.ch:80';
    $ENV{PERL_LWP_SSL_VERIFY_HOSTNAME} = 0;
    $ENV{"HTTPS_PROXY_USERNAME"} = 'zzrodin';
    $ENV{"HTTPS_PROXY_PASSWORD"} = 'as789HGI1'; 
}

#$url = 'http://feeds.feedburner.com/bitem/news';

my $url_page = $url;

my $response = my $res = $ua->get($url_page);

my $c = 0;
if ($response->is_success){


    my $str = $response->content;
    utf8::decode($str);
    my $feed = XML::FeedPP->new($str);



    $perl_response{'title'}         = $feed->title();
    $perl_response{'description'}   = $feed->description();
    $perl_response{'date'}          = $feed->pubDate();
    #$feed->copyright( $text );
    #$feed->link( $url );
    $perl_response{'lang'}          = $feed->language();

    foreach my $item ( $feed->get_item() ) {
        my $link        = $item->link();
        my $title       = $item->title();
        my $description = $item->description();

        my $hs = HTML::Restrict->new();
        $description = $hs->process($description);
        decode_entities($description);

        my $date        = $item->pubDate();
        my %items;
        $items{link}         = $link;
        $items{title}        = $title;
        $items{description}  = $description;
        $items{date}         = $date;
        push @{$perl_response{'items'}},\%items;

        $c++;
    }
    $perl_response{'count'} = $c;

    if ($c<1) {
        $perl_response{'error'} ='rss-link-not-found';
    }
    else {
       $perl_response{'error'} = 'none';
    }
}
else {
  $perl_response{'error'} ='error-'.$response->code;
}
$perl_response{'code'} = $response->code;
$perl_response{'count'} = $c;



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
utf8::encode($json_response);
print $json_response;




