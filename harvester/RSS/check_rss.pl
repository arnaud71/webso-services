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
use JSON;
use CGI;

#### init


my $q               = CGI->new;
# prepare the JSON msg
my $json            = JSON->new->allow_nonref;
my $callback        = q{};
my %perl_response   = ();


################ CRAWLER CONST ###########

my $RANDOM_AGENT    = 1;       # activate simulation of a random browser name (better)
my $USE_PROXY       = 0;

my $PROXY           = $ResipiConfig::proxy;



# get params

my $url             = $ARGV[0]; #required


###### end of CONST


my $logconf = "
    log4perl.logger.crawler                         = TRACE, crawlerAppender
    log4perl.appender.crawlerAppender               = Log::Log4perl::Appender::File
    log4perl.appender.crawlerAppender.filename      = /var/log/webso/rss_checker.log
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
}

my $url_page = $url;

my $response = my $res = $ua->get($url_page);

my $c = 0;
if ($response->is_success) {
    my $feed = XML::FeedPP->new($response->content);

    foreach my $item ( $feed->get_item() ) {
        my $link    = $item->link();
        push @{$perl_response{'links'}},$link;
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

print $json_response;



