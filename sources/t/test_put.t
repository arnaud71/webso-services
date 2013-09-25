#### test unit for put.json
use strict;

use Test::More qw( no_plan);
use LWP::UserAgent;
use Config::Simple;
use URI::Encode qw(uri_encode uri_decode);
use JSON;
use Data::Dump qw(dd);




my %source = (
    source_url_s              => 'http://feeds.sciencedaily.com/sciencedaily/matter_energy/nanotechnology',
    source_type_s             => 'rss',
    source_user_s             => 'user_1',
    source_level_sharing_i    => '1',
);

my $json    = JSON->new->allow_nonref;

my $cfg = new Config::Simple('../../../webso.cfg');
my $webso_services = $cfg->param('webso_services');


# init user_agent
my $ua = LWP::UserAgent->new;
$ua->timeout(10);
$ua->env_proxy;

my $url_encoded = uri_encode($source{source_url_s});
my $params = '?source_url='.$url_encoded.'&source_type='.$source{source_type_s}.'&source_user='.$source{source_user_s}.'&source_level_sharing='.$source{source_level_sharing_i};

my $response = $ua->get($webso_services.'sources/put.json'.$params);
 
if ($response->is_success) {
     print $response->decoded_content;  # or whatever

     my $r_json = $json->decode( $response->decoded_content);
     #dd($r_json);
     #exit;
     
     # test if success in the response
     isnt($$r_json{success}, undef, "success need to be defined");
          
     # test if not error in the response     
     is($$r_json{error}, undef, "error need to be undefined");
     
     # test if success/responseHandler/status = 0 in the response
     
     # could test success/responseHandler/Qtime to be not less than 30s for instance ... to see
     
     # test all the query params to be in the response too
     is($$r_json{success}{responseHeader}{status},0,$$r_json{success}{responseHeader}{status}.'-> status: 0');
     for my $k ( keys %source ) {
        is($$r_json{$k},$source{$k},$source{$k}.'->'.$$r_json{$k});
     }
}
 else {
     die $response->status_line;
}


