#!/usr/bin/perl
######################################################################
# sources/get.json 
# 
# get webso objects
#
# inputs: any solr objects
#
# Contributors:
#   - Arnaud Gaudinat : 11/08/2013
######################################################################

use strict;
use CGI;
use JSON;
use lib "..";
use LWP::UserAgent;
use Config::Simple;
use Digest::MD5 qw(md5 md5_hex md5_base64);
use URI::Encode qw(uri_encode uri_decode);


my $q       = CGI->new;
my $cgi     = $q->Vars;

# prepare the JSON msg
my $json    = JSON->new->allow_nonref;

my $callback = q{};

my %perl_response = (    
    );



# reading the conf file
my $cfg     = new Config::Simple('../webso.cfg');

if (Config::Simple->error()) {
    push @{$perl_response{'error'}},'Config file error';
    $perl_response{'debug_msg'} = Config::Simple->error();
}
else {
    my $deb_mod = $cfg->param('debug');


    my $db_url              = $cfg->param('db_url');
    my $db_type             = $cfg->param('db_type');
    my $db_user             = $cfg->param('db_user');
    my $db_level_sharing    = $cfg->param('db_level_sharing');

    my $query = q{};


    foreach my $k (keys %$cgi) {
        if ($k ne 'callback') {
            $query .= '&fq='.$k.':'.$$cgi{$k};
        }
    }

    #push @{$perl_response{'error'}},'source_user required';


    if ($q->param('callback')) {
        $callback    = $q->param('callback');
    }


    if (!(exists $perl_response{'error'})) {

        if ($$cgi{$db_type} eq $cfg->param('t_source')) {
            my $id = 's_'.md5_hex($$cgi{$db_user}.$$cgi{$db_url}); #add s_ for source
            if ($$cgi{id} ne q{}) {
                $$cgi{id} = $id;
            }
        }

        my $json_text   = $json->pretty->encode($cgi);

        # concatenate query and response
        %perl_response = (%perl_response,%$cgi);


        # init user_agent
        my $ua = LWP::UserAgent->new;
        $ua->timeout(10);
        $ua->env_proxy;

        # accessing values:
        #my $db_source = $cfg->param('db_source').'update -H \'Content-type:application/json\' -d ';

        #my $response = $ua->request($req);

 

        my  $query_encoded = uri_encode(
            'collection1/select?q=*:*'
            .$query
            .'&wt=json&indent=true');


        my $response = $ua->get($cfg->param('ws_db').$query_encoded);
 
        if ($response->is_success) {
            $perl_response{success} = $json->decode( $response->decoded_content);  # or whatever
     
        }
        else {
            $perl_response{'error'} = 'sources server or service: '.$response->code;
            if ($deb_mod) {
                $perl_response{'debug_msg'} = $response->message;
            }
        }
    }
}

my $json_response   = $json->pretty->encode(\%perl_response);

if ($callback) { 
    print 'Access-Control-Allow-Origin: *';
    print 'Access-Control-Allow-Methods: GET'; 
    print "Content-type: application/javascript\n\n";
    $json_response   = $callback.'('.$json_response.');';
} else { 
    # Header for access via browser, curl, etc. 
    print "Content-type: application/json\n\n"; 
} 

print $json_response; 
 