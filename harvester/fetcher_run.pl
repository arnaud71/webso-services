#!/usr/bin/perl
#####################################################################
#
#  fetcher run
#  to run a fetch for an url
#
# input :
#   - url_to_fetch
#   - fetch_id (md5 of the url_to_fetch)
#   - fetcher_url (url of the original fetcher)
#   - user_agent (if null random)
#   - synchro (synchro or assynchronous communication)
#
# output :
#
#   if synchro
#       - content
#       - code
#       - error
#
#  @TODO:
#       - add asynchronous mode
#
#
#
#
####################################################################

use LWP::UserAgent;
use Config::Simple;
use URI::Encode qw(uri_encode uri_decode);
use JSON;
use CGI;

print "Content-type: application/json\n\n";
my $json    = JSON->new->allow_nonref;

my $cfg = new Config::Simple('../webso.cfg');
my $webso_services = $cfg->param('webso_services');


########### get params
my $q   = CGI->new;
my $url = q{};


if ($q->param('url')) {
    $url        = $q->param('url');
}
if ($q->param('callback')) {
    $callback   = $q->param('callback');
}


# init user_agent
my $ua = LWP::UserAgent->new;
$ua->timeout(10);
$ua->env_proxy;

my $url_encoded = $url;
my $params = '?url='.$url_encoded;

my $response = $ua->get($webso_services.'fetcher_agent/fetcher_agent.pl'.$params);

if ($cfg->param('debug')) {
    #print $webso_services.'fetcher_agent/fetcher_agent.pl'.$params."\n";
}

my $r_json;

if ($response->is_success) {
    $r_json = $json->decode( $response->decoded_content);
    if ($cfg->param('debug')) {
            #print $webso_services.'fetcher_agent/fetcher_agent.pl'.$params."\n";
            #print $$r_json{content};
    }

}
else {
    $$r_json{error} = 'service fetcher_agent is not accessible';
}


print $response->decoded_content;