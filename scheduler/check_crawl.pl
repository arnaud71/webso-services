#######################################
# check_crawl.pl
#
#
###########################################

use strict;
use LWP::UserAgent;
use Config::Simple;
use URI::Encode qw(uri_encode uri_decode);
use JSON;
use Data::Dump qw(dd);

my $json    = JSON->new->allow_nonref;

my $cfg = new Config::Simple('../webso.cfg');
my $webso_services = $cfg->param('webso_services');



my $db_url                  = $cfg->param('db_url');
my $db_type                 = $cfg->param('db_type');
my $db_user                 = $cfg->param('db_user');
my $db_level_sharing        = $cfg->param('db_level_sharing');
my $db_source_type          = $cfg->param('db_source_type');


my %source = (
    $db_type             => 'source',

);

# init user_agent
my $ua = LWP::UserAgent->new;
$ua->timeout(1000);
$ua->env_proxy;



#
my $params = '?'.$db_type.'='.$source{$db_type}
             ;

my $response = $ua->get($webso_services.'db/get.pl'.$params);


if ($response->is_success) {
    #print $response->decoded_content;  # or whatever
    my $r_json = $json->decode( $response->decoded_content);
    # check all services
    my $i = 0;
    while ($r_json->{success}{response}{docs}[$i]) {
        my $doc = $r_json->{success}{response}{docs}[$i];
        print $$doc{url_s}."\n";

        my $params = '?url='.$$doc{url_s};

        my $res_rss = $ua->get($webso_services.'harvester/RSS/get_rss.pl'.$params);


        my $r_json_rss;

        if ($res_rss->is_success) {
            $r_json_rss = $json->decode( $res_rss->decoded_content);
            dd($r_json_rss);
            exit;
        }
        else {
            $$r_json_rss{error} = 'service get_rss.pl is not accessible';
        }


        $i++;
    }


}
 else {
     die $response->status_line;
}