# test the check rss
use strict;

use Test::More tests => 15; # currently 3 by urls
use LWP::UserAgent;
use Config::Simple;
use URI::Encode qw(uri_encode uri_decode);
use JSON;
use Data::Dump qw(dd);

my @tab_url;


# list of rss to test

# feed buner
#push @tab_url,'http://feeds.sciencedaily.com/sciencedaily/matter_energy/nanotechnology';
push @tab_url,'http://feeds.feedburner.com/bitem/news';
# rss version 2.0 - google news
#push @tab_url,'http://news.google.com/?output=rss&q=technology';
# rss google blog
#push @tab_url,'http://www.google.com/search?q=shampoo%20hair&hl=en&tbm=blg&tbs=qdr:d&output=rss';
# rss version 2.0 - delicious
#push @tab_url,'http://feeds.delicious.com/v2/rss/tag/technology';
# rss bing
#push @tab_url,'http://www.bing.com/search?q=technology&format=rss';
# rss bing news
#push @tab_url,'http://www.bing.com/news/search?q=shampoo&format=RSS';
# rss yahoo blog
#push @tab_url,'http://blog.search.yahoo.com/rss?ei=UTF-8&p=shampoo';

my $json    = JSON->new->allow_nonref;

my $cfg = new Config::Simple('../../../webso.cfg');
my $webso_services = $cfg->param('webso_services');


my $ua = LWP::UserAgent->new;
$ua->timeout(10);
$ua->env_proxy;

foreach my $url (@tab_url) {
    my $url_encoded = $url;
    my $params = '?url='.$url_encoded;

    my $response = $ua->get($webso_services.'harvester/RSS/check_rss.pl'.$params);

    if ($cfg->param('debug')) {
        print $webso_services.'harvester/RSS/check_rss.pl'.$params."\n";
    }

    my $r_json;

    if ($response->is_success) {
        $r_json = $json->decode( $response->decoded_content);
        if ($cfg->param('debug')) {
            print $webso_services.'harvester/check_rss.pl'.$params."\n";
            print $$r_json{content};
        }
    }
    else {
        $$r_json{error} = 'service check_rss.pl is not accessible';
    }

    # test if response code 200 for $url
    is($$r_json{code}, '200', "http code response should be 200 and you get ".$$r_json{code});

    # test if not error
    is($$r_json{error}, 'none', "error should be 'none' and you get ".$$r_json{error});

    # test if content>1000 char

    ok($$r_json{count}>0, "number of links must be >0 and you get ".$$r_json{count});

}

