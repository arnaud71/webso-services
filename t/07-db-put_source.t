#### test unit for put.pl (for source)
use strict;

use Test::More qw( no_plan);
use LWP::UserAgent;
use Config::Simple;
use URI::Encode qw(uri_encode uri_decode);
use JSON;
use Data::Dump qw(dd);
use FindBin qw($Bin);

my $json    = JSON->new->allow_nonref;

my $cfg = new Config::Simple('$Bin/../webso.cfg');
my $webso_services = $cfg->param('webso_services');



my $db_url                  = $cfg->param('db_url');
my $db_type                 = $cfg->param('db_type');
my $db_user                 = $cfg->param('db_user');
my $db_level_sharing        = $cfg->param('db_level_sharing');
my $db_source_type          = $cfg->param('db_source_type');



my %source = (
    $db_url              => 'http://feeds.sciencedaily.com/sciencedaily/matter_energy/nanotechnology',
    $db_type             => 'source',
    $db_user             => 'administrateur',
    $db_level_sharing    => 1,
    $db_source_type      => 'rss',
);





# init user_agent
my $ua = LWP::UserAgent->new;
$ua->timeout(10);
$ua->env_proxy;


$source{$db_url} = uri_encode($source{$db_url});

#my $params = '?source_url='.$url_encoded.'&source_type='.$source{source_type_s}.'&source_user='.$source{source_user_s}.'&source_level_sharing='.$source{source_level_sharing_i};

my $params = '?'.$db_url.'='.$source{$db_url}
             .'&'.$db_type.'='.$source{$db_type}
             .'&'.$db_user.'='.$source{$db_user}
             .'&'.$db_level_sharing.'='.$source{$db_level_sharing}
             .'&'.$db_source_type.'='.$source{$db_source_type}
             ;

my $response = $ua->get($webso_services.'db/put.pl'.$params);

if ($response->is_success) {
     #print $response->decoded_content;  # or whatever

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
        is($$r_json{$k},$source{$k},$source{$k}."->$k->".$$r_json{$k});
     }
}
 else {
     die $response->status_line;
}


