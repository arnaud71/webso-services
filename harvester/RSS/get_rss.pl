#!/usr/bin/perl
#####################################################################
#
#  rss harvester
#
#
# input:
#   - url : rss url to fetch
#   - crawl_link : flag
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
use CGI;
use HTML::Restrict;


my $cfg = new Config::Simple('../../webso.cfg');
my $webso_services = $cfg->param('webso_services');
my $q               = CGI->new;


my $RANDOM_SLEEP    = $cfg->param('random_sleep');          # active sleep during a random period of time between 2 crawl of the same site
my $MIN_TIME_SLEEP  = $cfg->param('min_time_sleep');        # min sleep time between 2 crawl of the same site
my $MAX_TIME_SLEEP  = $cfg->param('max_time_sleep');        # max sleep time between 2 crawl of the same site


# get params
my $callback    = '';
my $url;
my $debug       = 1;
my $crawl_link  = 'true';

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



my $json    = JSON->new->allow_nonref;

if ($q->param('url')) {
        $url    = $q->param('url');
}
else {
    #$url     = 'http://news.google.com/news?pz=1&cf=all&ned=fr_ch&hl=fr&output=rss&q=iphone';
    $url     = 'http://feeds.feedburner.com/bitem/news';
}


if ($q->param('crawl_link')) {
        $crawl_link    = $q->param('crawl_link');
}
else {
    $crawl_link     = 'true';
}

if ($q->param('nb')) {
        $nb    = $q->param('nb');
}
else {
    $nb     = '0';
}

if ($q->param('callback')) {
    $callback    = $q->param('callback');
}


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
    $r_json = $json->decode( $response->content);
    get_logger("crawler")->trace("$url type RSS fetched");
    #################### type RSS   #########

    my $feed = XML::FeedPP->new($$r_json{content});
    $$final_json{error} = $$r_json{error};
    my $c = 0;
    my @tab_res;
    foreach my $item ( $feed->get_item() ) {
        # get meta-info from RSS
        if (($nb!=0) && ($c+1>$nb)) {
            last;
        }
        my $link    = $item->link();
        if ($debug) {
                print STDERR $link."\n";
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
            my $hs = HTML::Restrict->new();

            my $title   = $item->title();

            $title = $hs->process($title);  # clean html

            my $meta_content  = $item->description();  #http::strip doesn't support utf8


            $meta_content = $hs->process($meta_content);  # clean html


            # get the date from RSS
            my $date_rss = $item->pubDate();
            my $str_date = q{};

            if (!(defined $item->pubDate())) {
                my $tm = localtime;
                $str_date = sprintf("%04d-%02d-%02d".'T'. "%02d:%02d:%02d".'Z', $tm->year+1900,($tm->mon)+1, $tm->mday, $tm->hour, $tm->min, $tm->sec);
            }
            else {
                my $fmt     = DateTime::Format::RSS->new;
                my $dt      = $fmt->parse_datetime($date_rss);
                $str_date   = $fmt->format_datetime($dt);
                $str_date   .= 'Z';
            }

            my $tm = localtime;
            $datetime = sprintf("%04d-%02d-%02d".'T'. "%02d:%02d:%02d".'Z', $tm->year+1900,($tm->mon)+1, $tm->mday, $tm->hour, $tm->min, $tm->sec);
            $link = clean_url($link);


            my $h;
            if ($crawl_link eq 'true') {
                # new fetch get the content of the link
                my $ua2 = LWP::UserAgent->new;

                my $params      = '?url='.$link;
                my $res_link    = $ua2->get($webso_services.'harvester/fetcher_run.pl'.$params);
                my $r_json_link = $json->decode( $res_link->content);


                if ($res_link->code == 403) {       # stop if access denied
                    get_logger("crawler")->trace("$url 403 access denied: job $link stopped");
                    exit;
                }



                #print $$r_json_link{cached}."\n";

                if (($$r_json_link{cached} eq 'false') &&  ($RANDOM_SLEEP)) {
                    my $sleep_time = int(rand($MAX_TIME_SLEEP-$MIN_TIME_SLEEP))+$MIN_TIME_SLEEP;
                    sleep($sleep_time);
                    #print "wait!!\n";

                }
                if (($res_link->is_success) || ($res_link->is_redirect)){

                    #print $$r_json_link{content}


                    $$h{content}        = $$r_json_link{content};
                    $$h{code_link}      = $$r_json_link{code};
                    $$h{error_link}     = $$r_json_link{error};

                }
            }


            $$h{link}           = $link;
            $$h{title}          = $title;
            $$h{meta_content}   = $meta_content;
            $$h{date}           = $str_date;
            $$h{nb}             = $c+1;

            push @tab_res, $h;
            $c++;
        }
        #last; #stop on first item
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
    print "Content-type: application/javascript; charset=utf-8\n\n";
    $json_response   = $callback.'('.$json_response.');';
} else {
    # Header for access via browser, curl, etc.
    print "Content-type: application/json; charset=utf-8\n\n";
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


