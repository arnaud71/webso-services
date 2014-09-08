#!/usr/bin/perl
######################################################################
# sources/delete_q.json
#
# removes sources to webso from a query
#
# inputs:
# Contributors:
#   - Arnaud Gaudinat : 07/2014
######################################################################

use strict;
use CGI;
use JSON;
use lib "..";
use LWP::UserAgent;
use Config::Simple;
use Digest::MD5 qw(md5 md5_hex md5_base64);
use Data::Dump qw(dd);



my $q       = CGI->new;
my $cgi     = $q->Vars;

# prepare the JSON msg

my $json    = JSON->new->allow_nonref;

my %perl_response = (
    );

# print json header
print $q->header('application/json');

# reading the conf file
my $cfg     = new Config::Simple('../webso.cfg');

if (Config::Simple->error()) {
    $perl_response{'error'} = 'Config file error';
    $perl_response{'debug_msg'} = Config::Simple->error();
}
else {
	my $deb_mod = $cfg->param('debug');


#   my $ID              = $cfg->param('id');
	my $query 		= $$cgi{'query'};


#    my $id = q{};
#    if ($q->param($ID)) {
#        $id     = $q->param($ID);
#    }


#my $id = md5_hex($source_user.$source_url);
    $query = "{\"delete\":{\"query\":\"$query\"}}";

    my $json_text   = $query;



    # init user_agent
    my $ua = LWP::UserAgent->new;
    $ua->timeout(10);
    $ua->env_proxy;



    my $req = HTTP::Request->new(
        POST => $cfg->param('ws_db').'update',
        #POST => 'http://localhost:8983/solr/collection1/update?wt=json'
    );
    $req->content_type('application/json');
    $req->content($json_text);

    my $response = $ua->request($req);

    #print $query;
    #dd($req);
    #exit;


    if ($response->is_success) {
        print $response->decoded_content;  # or whatever
    }
    else {
        $perl_response{'error'} = 'sources server or service: '.$response->code;
        if ($deb_mod) {
            $perl_response{'debug_msg'} = $response->message;
        }
    }
}


my $json_response   = $json->pretty->encode(\%perl_response);

print $json_response;


