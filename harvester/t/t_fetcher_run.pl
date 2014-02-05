# test the fetcher_run
use strict;

use Test::More tests => 12; # currently 3 by urls
use LWP::UserAgent;
use Config::Simple;
use URI::Encode qw(uri_encode uri_decode);
use JSON;
use Data::Dump qw(dd);

my @tab_url;

# list of url to test
push @tab_url,'http://feeds.sciencedaily.com/sciencedaily/matter_energy/nanotechnology';
#push @tab_url,'http://feeds.feedburner.com/bitem/news';
#push @tab_url,'https://www.hon.ch';


my $json    = JSON->new->allow_nonref;

my $cfg = new Config::Simple('../../webso.cfg');
my $webso_services = $cfg->param('webso_services');


# init user_agent
my $ua = LWP::UserAgent->new;
$ua->timeout(10);
$ua->env_proxy;


foreach my $url (@tab_url) {
    my $url_encoded = $url;
    my $params = '?url='.$url_encoded;

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

    # test if response code 200 for $url
    is($$r_json{code}, '200', "http code response should be 200 and you get ".$$r_json{code});

    # test if not error
    is($$r_json{error}, 'none', "error should be 'none' and you get ".$$r_json{error});

    # test if content>1000 char

    ok(length($$r_json{content})>1000, "length of content should be greater than 1000 char");

}