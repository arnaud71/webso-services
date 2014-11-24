# test the get_querysearch
#
# @todo : should improve with more tests
use strict;

use Test::More tests => 18;
use LWP::UserAgent;
use Config::Simple;
use URI::Encode qw(uri_encode uri_decode);
use JSON;
use Data::Dump qw(dd);

my @tab_url;

my $json    = JSON->new->allow_nonref;

my $cfg = new Config::Simple('webso.cfg');
my $webso_services = $cfg->param('webso_services');


my @tab_query = (
    ['iphone','google_news'],
    ['ipad','yahoo_news'],
    ['ipad','faroo_news'],
    ['ipad','bing_news'],
    ['ipad','google_blog'],
    ['ipad','reddit'],
);

my $ua = LWP::UserAgent->new;
$ua->timeout(10);
$ua->env_proxy;

foreach my $item (@tab_query) {
    print "test $$item[1]\n";
    my $params = '?query='.$$item[0].'&typeQuery='.$$item[1];
    #print $params."\n";

    my $response = $ua->get($webso_services.'harvester/QUERYSEARCH/get_querysearch.pl'.$params);

    my $r_json;


    if ($response->is_success) {
        $r_json = $json->decode( $response->decoded_content);


        if ($cfg->param('debug')) {
            dd($r_json);
            print $webso_services.'harvester/QUERYSEARCH/get_querysearch.pl'.$params."\n";
            print $$r_json{content};
        }
    }
    else {
        $$r_json{error} = 'service get_rss.pl is not accessible';
        if ($cfg->param('debug')) {
            dd($response);
        }
    }

    $$r_json{code} = $response->code;
    # test if response code 200 for $url
    is($$r_json{code}, '200', "http code response should be 200 and you get ".$$r_json{code});

    # test if not error
    is($$r_json{error}, 'none', "error should be 'none' and you get ".$$r_json{error});

    # test if content>1000 char

    ok($$r_json{count}>2, "number of links must be >2 and you get ".$$r_json{count});

}
