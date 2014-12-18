#!/usr/bin/perl
#######################################
# check_crawl.pl
#
#
###########################################

use strict;
use LWP::UserAgent;
use Config::Simple;
use URI::Encode qw(uri_encode uri_decode);
use JSON;
use Data::Dump qw(dd);
use IO::Socket::INET;
use Digest::MD5 qw(md5 md5_hex md5_base64);
use Log::Log4perl qw(:easy);
use Time::localtime;
use lib '..';
use Tools;
use FindBin qw($Bin);


my $json    = JSON->new->allow_nonref;

my $cfg                     = new Config::Simple("$Bin/../webso.cfg");
&Tools::init("$Bin/..");
my $webso_services          = $cfg->param('webso_services');
my $db_type                 = $cfg->param('db_type');
my $db_source_type          = $cfg->param('db_source_type');

my $logconf = "
    log4perl.logger.crawler                         = TRACE, crawlerAppender
    log4perl.appender.crawlerAppender               = Log::Log4perl::Appender::File
    log4perl.appender.crawlerAppender.filename      = ".$cfg->param('log_dir')."crawl_checker.log
    log4perl.appender.crawlerAppender.layout        = PatternLayout
    log4perl.appender.crawlerAppender.layout.ConversionPattern=%d - %m{chomp}%n

";


Log::Log4perl::init(\$logconf);


#my $test_data ='<html><body><h1>titre document</h1> et le reste <body></html>';
#extract_tika_content(\$test_data);
#exit;

# init user_agent
my $ua = LWP::UserAgent->new;
$ua->timeout(1000);
#$ua->env_proxy;

# my $params = '?'.$db_type.'=source&'.db_source_type.;
# my $response = $ua->get($webso_services.'db/get.pl'.$params);
my $start = 0;
my $rows  = 10;
my $params = '?qt=select&q=type_s:source&wt=json&indent=true';
# my $params = '?qt=select&q=type_s%3Asource+AND+(source_type_s%3ARSS+OR+source_type_s%3Arss)&wt=json&indent=true';
my $response = $ua->get($webso_services.'db/query.pl'.$params.'&start='.$start.'&rows='.$rows);

if ($response->is_success) {
    my $error_msg = q{};

    my $r_json = $json->decode($response->content);
    my $max = $r_json->{success}{response}{numFound};
    my $j = 0; #Counter for the query loop
    # print $response->content;

    while ($j*$rows < $max){
        my $i = 0;
        if($j != 0){
            $start = $j*$rows;
            $response = $ua->get($webso_services.'db/query.pl'.$params.'&start='.$start.'&rows='.$rows);
            $r_json = $json->decode($response->content);
        }
        # check all services
        while ($r_json->{success}{response}{docs}[$i]) {
            my $source = $r_json->{success}{response}{docs}[$i];
            #$$doc{url_s} = 'http://feeds.feedburner.com/bitem/news';
            my $crawl_link      = 'true';
            my $indexing        = 'true';
            # print $j.'-'.$i.'-'.$r_json->{success}{response}{docs}[$i]{url_s}."\n";
            # my $rss_json = Tools::fetchDocSource($source,$crawl_link,$indexing);
            $i++;
            #exit;
        }
        $j++;
    }
    #if ($error_msg) {
        #$$r_json_rss{error} = $error_msg;
    #}
}
else {
    die $response->status_line;
}
