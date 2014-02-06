#!/usr/bin/perl
#####################################################################
#
#  rss harvester
#
# add redirection 6/2012
# add url cleaning (\r\n space ...)
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


my $cfg = new Config::Simple('../webso.cfg');


# get params

my $url         = $ARGV[0]; #required
my $user_id     = $ARGV[1];
my $debug       = $ARGV[2];

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


my $url     = 'http://feeds.boston.com/boston/business/technology';


my $json    = JSON->new->allow_nonref;

my $cfg = new Config::Simple('../../webso.cfg');
my $webso_services = $cfg->param('webso_services');


if ($url eq q{} ) {
    get_logger("crawler")->trace("url to crawl is empty");
    exit;
}



my $url_page = $url;

my $ua = LWP::UserAgent->new;
my $response = my_get($ua, $url_page);

my $response = $ua->get($webso_services.'fetcher_agent/fetcher_agent.pl'.$params);

    if ($cfg->param('debug')) {
        print $webso_services.'fetcher_agent/fetcher_run.pl'.$params."\n";
    }

    my $r_json;
    if ($response->is_success) {
        $r_json = $json->decode( $response->decoded_content);
        if ($cfg->param('debug')) {
            print $webso_services.'harvester/fetcher_run.pl'.$params."\n";
            print $$r_json{content};
        }
    }
    else {
        $$r_json{error} = 'service fetcher_agent is not accessible';
    }

exit;


if (($response->is_success) || ($response->is_redirect)) {
    get_logger("crawler")->trace("$url_page type RSS fetched");
    #################### type RSS   #########

        my $feed = XML::FeedPP->new($response->content);
        my $c = 0;
        foreach my $item ( $feed->get_item() ) {
            # get meta-info from RSS
            my $link    = $item->link();
            if ($debug) {
                print $link."\n";
            }
            # if google news rss change the link
            $link =~ s/http:\/\/news\.google\.com\/(.*?)&url=(.*?)/$2/;
            # if google rss from alert change the link
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
            if ($RANDOM_AGENT) {
            $ua2->agent(rand_ua("browsers"));
            }
            $ua2->timeout(30);
            #$ua2->env_proxy;
            $ua2->proxy(['http'], $PROXY);
            my $cookies=new HTTP::Cookies(file=>'./cookies.dat',autosave=>1);
            $ua2->cookie_jar($cookies);
            $link = clean_url($link);
            my $res_link    = my_get($ua2, $link);


            if ($res_link->code == 403) {       # stop if access denied
                get_logger("crawler")->trace("$url_page 403 access denied: job $link stopped");
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
               #get_logger("crawler")->trace($res_link->code." ".$res_link->content);

               if (($res_link->is_success) || ($res_link->is_redirect)){
                    $nb++;
                    #modif_job();

                }  #end if respons2 success
#                add_page(
#                    $res_link->content,
#                    $res_link->code,
#                    $url,
#                    $link,
#                    $type
#                );
            }
        } #end foreach

}
else {
    get_logger("crawler")->trace("$url_page type RSS not fetched ".$response->code);
    print STDERR "$url_page type RSS not fetched ".$response->code;
}


######################## end of main #################################
######################################################################



####################################################################
### add_page add content of page in database
####################################################################
sub add_page {

}



#########################################################
### is_fetched_page only for RSS and based on url_page MD5
#########################################################
sub is_fetched_page {

}



#########################################################
### add_meta, add what meta we found during the processing
#########################################################
sub add_meta {
}

#########################################################
### update_page_content, update the content of a page
#########################################################
sub update_page_content {

}



sub clean_url {
    my $url = shift @_;
    $url =~ s/\n//gs;
    $url =~ s/^ +//gs;
    $url =~ s/ +$//gs;
    $url =~ s/^'//;
    $url =~ s/'$//;

    return $url;
}