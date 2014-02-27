package RssInterface;


use strict;
use LWP::UserAgent;
use Config::Simple;
use URI::Encode qw(uri_encode uri_decode);
use JSON;
use Data::Dump qw(dd);

my $cfg = new Config::Simple('../../webso.cfg');
my $webso_services = $cfg->param('webso_services');



sub check_rss {
    my $url = shift @_;

    my $r_json;
    my $json    = JSON->new->allow_nonref;

    my $params = '?url='.$url;


    my $ua = LWP::UserAgent->new;
    $ua->timeout(10);
    my $response = $ua->get($webso_services.'harvester/RSS/check_rss.pl'.$params);


    if ($response->is_success) {
        $r_json = $json->decode($response->decoded_content);
    }
    else {
      $$r_json{error} = 'service check_rss.pl is not accessible';
    }
    return ($r_json);
}

return 1;