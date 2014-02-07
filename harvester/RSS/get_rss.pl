#!/usr/bin/perl
#####################################################################
#
#  rss harvester
#
#
# input:
#   - rss url
#
####################################################################

use strict;


use CGI::Carp qw(fatalsToBrowser);
use XML::FeedPP;
use Digest::MD5 qw(md5 md5_hex md5_base64);
use DateTime::Format::RSS;
use Time::localtime;
use Log::Log4perl qw(:easy);
use Config::Simple;
use JSON;
use LWP::UserAgent;


my $cfg = new Config::Simple('../../webso.cfg');
my $webso_services = $cfg->param('webso_services');


my $RANDOM_SLEEP    = $cfg->param('random_sleep');          # active sleep during a random period of time between 2 crawl of the same site
my $MIN_TIME_SLEEP  = $cfg->param('min_time_sleep');        # min sleep time between 2 crawl of the same site
my $MAX_TIME_SLEEP  = $cfg->param('max_time_sleep');        # max sleep time between 2 crawl of the same site


# get params
my $callback  = '';
my $url;
my $debug       = 1;

###### end of CONST


my $logconf = "
    log4perl.logger.crawler                         = TRACE, crawlerAppender
    log4perl.appender.crawlerAppender               = Log::Log4perl::Appender::File
    log4perl.appender.crawlerAppender.filename      = ".$cfg->param('log_dir')."rss_harvester.log
    log4perl.appender.crawlerAppender.layout        = PatternLayout
    log4perl.appender.crawlerAppender.layout.ConversionPattern=%d - %m{chomp}%n

";

Log::Log4perl::init(\$logconf);


my $datetime    = q{}; # string to keep local time for each crawl
my $nb          = 0;


my $url     = 'http://feeds.feedburner.com/bitem/news';
my $json    = JSON->new->allow_nonref;


if ($url eq q{} ) {
    get_logger("crawler")->trace("url to crawl is empty");
    exit;
}


my $url_encoded = $url;
my $params = '?url='.$url_encoded;

my $ua = LWP::UserAgent->new;

my $response = $ua->get($webso_services.'harvester/fetcher_run.pl'.$params);
my $r_json;
my $final_json;

$$final_json{error} = 'none';

if (($response->is_success) || ($response->is_redirect)) {
    $$final_json{url} = $url;
    $r_json = $json->decode( $response->decoded_content);
    get_logger("crawler")->trace("$url type RSS fetched");
    #################### type RSS   #########

    my $feed = XML::FeedPP->new($$r_json{content});
    $$final_json{error} = $$r_json{error};
    my $c = 0;
    my @tab_res;
    foreach my $item ( $feed->get_item() ) {
        # get meta-info from RSS
        my $link    = $item->link();
        if ($debug) {
                print $link."\n";
        }
        # if google news rss clean the link
        $link =~ s/http:\/\/news\.google\.com\/(.*?)&url=(.*?)/$2/;
        # if google rss from alert clean the link
        $link =~ s/http:\/\/www\.google\.com\/url?sa=X&q=(.*?)&ct=ga/$1/; # http://www.google.com/url?sa=X&q=http://www.reuters.com/article/2011/10/05/markets-stocks-idUSN1E7941Q420111005&ct=ga&cad=CAcQARgBIAAoATAAOABAu_rM9ARIAlAAWABiBWVuLVVT&cd=fxSzk4Rh8U4&usg=AFQjCNEIZ9vZJg
        # if come from boston.com take pheedo:origLink if present
        if ($item->get('pheedo:origLink')) {
            $link = $item->get('pheedo:origLink');
            #print STDERR $link."\n";
        }
        if (is_fetched_page($link)) {  # next link if already fetched from foreach loop
            next;
        }
        if ($link !~/mp3$/) {
            my $title   = $item->title();
            # get the date from RSS
            my $date_rss = $item->pubDate();
            my $str_date = q{};

            if (!(defined $item->pubDate())) {
                my $tm = localtime;
                $str_date = sprintf("%04d-%02d-%02d' '%02d:%02d:%02d", $tm->year+1900,($tm->mon)+1, $tm->mday, $tm->hour, $tm->min, $tm->sec);
            }
            else {
                my $fmt     = DateTime::Format::RSS->new;
                my $dt      = $fmt->parse_datetime($date_rss);
                $str_date   = $fmt->format_datetime($dt);
                $str_date =~ s/T/ /;
            }

            my $tm = localtime;
            $datetime = sprintf("%04d-%02d-%02d %02d:%02d:%02d", $tm->year+1900,($tm->mon)+1, $tm->mday, $tm->hour, $tm->min, $tm->sec);

            # new fetch

            my $ua2 = LWP::UserAgent->new;
            $link = clean_url($link);

            my $params = '?url='.$link;
            my $res_link    = my $response = $ua->get($webso_services.'harvester/fetcher_run.pl'.$params);


            if ($res_link->code == 403) {       # stop if access denied
                get_logger("crawler")->trace("$url 403 access denied: job $link stopped");
                exit;
            }


            # if fetch OK we add meta
            add_meta(
                $link,
                $url,    #url of the job
                $title,
                $str_date,
                'rss'
            );

            if ($RANDOM_SLEEP) {
                my $sleep_time = int(rand($MAX_TIME_SLEEP-$MIN_TIME_SLEEP))+$MIN_TIME_SLEEP;
                sleep($sleep_time);
            }

            my $r_json_link;
            if (($res_link->is_success) || ($res_link->is_redirect)){
                $r_json_link = $json->decode( $response->decoded_content);
                #print $$r_json_link{content}
                my $h;
                $$h{link}       = $link;
                $$h{title}      = $title;
                $$h{date}       = $str_date;
                $$h{content}    = $$r_json_link{content};
                $$h{code_link}  = $$r_json_link{code};
                $$h{error_link} = $$r_json_link{error};
                push @tab_res, $h;
                $c++;
            }
        }
    } #end foreach
    $$final_json{items} = \@tab_res;
    $$final_json{count} = $c;
    $$final_json{code}  = $response->code;
}
else {
    $$final_json{error} = 'service fetcher_agent is not accessible';
}


my $json_response   = $json->pretty->encode($final_json);


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


#########################################################
### add_meta, add what meta we found during the processing
#########################################################
sub add_meta {
}


########################################################
### is_fetched_page only for RSS and based on url_page MD5
#########################################################
sub is_fetched_page {

}

######################################################
### just a simple string cleaning
######################################################
sub clean_url {
    my $url = shift @_;
    $url =~ s/\n//gs;
    $url =~ s/^ +//gs;
    $url =~ s/ +$//gs;
    $url =~ s/^'//;
    $url =~ s/'$//;
    return $url;
}


