# test the get rss
#
# @todo : should improve with more tests
use strict;

use Test::More tests => 6;
use LWP::UserAgent;
use Config::Simple;
use URI::Encode qw(uri_encode uri_decode);
use JSON;
use Data::Dump qw(dd);

my @tab_url;

push @tab_url,'http://feeds.feedburner.com/bitem/news';
push @tab_url,'http://www.tdg.ch/high-tech/rss.html';

my $json    = JSON->new->allow_nonref;

my $cfg = new Config::Simple('webso.cfg');
my $webso_services = $cfg->param('webso_services');


my $ua = LWP::UserAgent->new;
$ua->timeout(10);
$ua->env_proxy;

foreach my $url (@tab_url) {
    my $url_encoded = $url;
    my $params = '?nb=3&url='.$url_encoded;

    my $response = $ua->get($webso_services.'harvester/RSS/get_rss.pl'.$params);

    my $r_json;


    if ($response->is_success) {
        $r_json = $json->decode( $response->decoded_content);
        if ($cfg->param('debug')) {
            dd($r_json);
            print $webso_services.'harvester/RSS/get_rss.pl'.$params."\n";
            print $$r_json{content};
        }
    }
    else {
        $$r_json{error} = 'service get_rss.pl is not accessible';
        if ($cfg->param('debug')) {
            dd($response);
        }
    }

    # test if response code 200 for $url
    is($$r_json{code}, '200', "http code response should be 200 and you get ".$$r_json{code});

    # test if not error
    is($$r_json{error}, 'none', "error should be 'none' and you get ".$$r_json{error});

    # test if content>1000 char

    ok($$r_json{count}>2, "number of links must be >2 and you get ".$$r_json{count});

}
