#!/usr/bin/perl
#####################################################################
#
#  query search harvester (on google news, google blog, delicious)
#
#
# input:
#   - query : query to search
#
#
####################################################################

use strict;


use CGI::Carp qw(fatalsToBrowser);
use lib '../..';
use Digest::MD5 qw(md5 md5_hex md5_base64);
use DateTime::Format::RSS;
use Time::localtime;
use Log::Log4perl qw(:easy);
use Config::Simple;
use JSON;
use LWP::UserAgent;
use CGI;
use Tools;



my $cfg = new Config::Simple('../../webso.cfg');
my $webso_services = $cfg->param('webso_services');
my $q       = CGI->new;
my $cgi     = $q->Vars;


my $RANDOM_SLEEP    = $cfg->param('random_sleep');          # active sleep during a random period of time between 2 crawl of the same site
my $MIN_TIME_SLEEP  = $cfg->param('min_time_sleep');        # min sleep time between 2 crawl of the same site
my $MAX_TIME_SLEEP  = $cfg->param('max_time_sleep');        # max sleep time between 2 crawl of the same site


my $db_url                  = $cfg->param('db_url');


# get params
my $callback    = '';
my $query       = '';
my $debug       = 1;
my $crawl_link  = 'false',


###### end of CONST




my $datetime    = q{}; # string to keep local time for each crawl
my $nb          = 0;



my $json    = JSON->new->allow_nonref;

if ($q->param('query')) {
        $query    = $q->param('query');
}
else {
    $query     = '';
}




################### query googlenews

# pz = 1 (0 or 1)
# ned = region
# cf : don't use cf
#

my $googleNewsEn = 'http://news.google.com/news?pz=1&hl=en&q=MYQUERY&output=rss';
my $googleNewsFr = 'http://news.google.com/news?pz=1&hl=fr&q=MYQUERY&output=rss';




my $json_response   = $json->pretty->encode($final_json);


my %source;



$googleNewsFr =~ s/MYQUERY/$query/;
$source{$db_url} = $googleNewsFr;

my $crawl_link  = 'false';
my $indexing    = 'false';
my $source_json = Tools::fetchDocSource(\%source,$crawl_link,$indexing);

print dd($source_json);exit;

if ($callback) {
    print 'Access-Control-Allow-Origin: *';
    print 'Access-Control-Allow-Methods: GET';
    print "Content-type: application/javascript; charset=utf-8\n\n";
    $json_response   = $callback.'('.$json_response.');';
} else {
    # Header for access via browser, curl, etc.
    print "Content-type: application/json; charset=utf-8\n\n";
}

print $json_response;

