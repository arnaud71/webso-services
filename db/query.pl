#!/usr/bin/perl
######################################################################
# query.pl
# 
# solr front-end
#
# inputs: solr query vars
#
# TODO add token and timeout for security purpose
#
# Contributors:
#   - Clement MILLET : 1/12/2014
######################################################################

use strict;
use CGI;
use JSON;
use lib "..";
use LWP::UserAgent;
use Config::Simple;
use Digest::MD5 qw(md5 md5_hex md5_base64);
use URI::Encode qw(uri_encode uri_decode);
use FindBin qw($Bin);

my $q       = CGI->new;
my $cgi     = $q->Vars;

# prepare the JSON msg
my $json    = JSON->new->allow_nonref;
my $json_text = q{};

my $callback = q{};

my %perl_response = (
    );

my $query = q{};
my $action = '';


# reading the conf file
my $cfg     = new Config::Simple("$Bin/../webso.cfg");

if (Config::Simple->error()) {
    push @{$perl_response{'error'}},'Config file error';
    $perl_response{'debug_msg'} = Config::Simple->error();
}
else {
    my $deb_mod = $cfg->param('debug');
    
    # if($q->param('POSTDATA')){
    #     my @var = $json->decode($$cgi{'POSTDATA'});
    #     if($var[0]->{token_s})
    # }
    # else{
    #     if ($q->param('token_s')) {
    # }


    # $query  = 'q='.'token_s:'.$cgi_user.' AND email_s:'.$cgi_mail;
    # my $query_encoded = uri_encode(
    # "collection1/select?"
    # .$query #. ' AND jeton_s:false'
    # .'&wt=json&indent=true');
                
    # my $response_2 = $ua->get($cfg->param('ws_db').$query_encoded);
    # my $response_text = $json->decode($response_2->decoded_content);                

    # if ($response_2->is_success) {


    if ($q->param('qt')) {
        foreach my $k (keys %$cgi) {
            if ($k ne 'callback') {
                if ($k eq 'qt') {
                    $action = $$cgi{$k};
                }
                else {
                    $query .= '"'.$k.'":"'.$$cgi{$k}.'",';
                    #$query .= '"'.$k.'":{"set":"'.$$cgi{$k}.'"},';
                }
            }
        }
        $json_text = '{'.$query.'}';
        print $json_text;

    }
    else{
        if($q->param('POSTDATA')){
            my @var = $json->decode($$cgi{'POSTDATA'});
            foreach my $k (keys $var[0]) {
                if ($k ne 'callback') {
                    if ($k eq 'qt') {
                        $action = $$cgi{$k};
                    }
                    else {
                       $query .= '"'.$k.'":{"set":"'.$var[0]{$k}.'"},';
                    }
                }
            }
            $json_text = '{'.$query.'}';
            print $json_text;
        }
        else{
            push @{$perl_response{'error'}},'Not a good query';
        }
    }

    if ($q->param('callback')) {
        $callback    = $q->param('callback');
    }

    if (!(exists $perl_response{'error'})) {

        # init user_agent
        # my $ua = LWP::UserAgent->new;
        # $ua->timeout(10);
        # $ua->env_proxy;

        # my $req = HTTP::Request->new(
        #     POST => $cfg->param('ws_db').$action.'?'
        # );
        # $req->content_type('application/json');
        # $req->content('['.$json_text.']');

        # my $res = $ua->request($req);
        # print $res->content;

        # if ($res->is_success) {
        #     $perl_response{success} = $json->decode($res->content);
        # }
        # else {
        #     $perl_response{'error'} = 'sources server or service: '.$res->code;
        #     if ($deb_mod) {
        #         $perl_response{'debug_msg'} = $res->message;
        #     }
        # }
        $query = '';
        foreach my $k (keys %$cgi) {
            # if ($k eq 'rows') {
            #     $query .= '&rows='.$$cgi{$k};
            # }
            # elsif ($k eq 'start') {
            #         $query .= '&start='.$$cgi{$k};
            #     }
            # elsif ($k eq 'sort') {
            #             $query .= '&sort='.$$cgi{$k};
            #         }
            # elsif ($k ne 'callback') {
            #     $query .= '&fq='.$k.':'.$$cgi{$k};
            # }
            if ($k eq 'qt') {
                $action = $$cgi{$k};
            }
            elsif (!($k eq 'callback' || $k eq 'json.wrf')) {
                $query .= $k.'='.$$cgi{$k}.'&';
            }
        }
        if ($q->param('callback')) {
            $callback = $q->param('callback');
        }
        if ($q->param('json.wrf')) {
            $callback = $q->param('json.wrf');
        }

        # init user_agent
        my $ua = LWP::UserAgent->new;
        $ua->timeout(10);
        $ua->env_proxy;

        my  $query_encoded = uri_encode(
            'collection1/'.$action.'?'
            .$query);
            #.'&wt=json&indent=true');
        $perl_response{success} = $query_encoded;
        #die $query_encoded;

        my $response = $ua->get($cfg->param('ws_db').$query_encoded);
        #print $response->content;

        if ($response->is_success) {
            $perl_response{success} = $json->decode( $response->content);  # or whatever
        }
    }
}

my $json_response   = $json->pretty->encode(\%perl_response);

if ($callback) {
    print 'Access-Control-Allow-Origin: *';
    print 'Access-Control-Allow-Methods: GET, POST, OPTIONS'."\n";
    print "Content-type: application/javascript; charset=utf-8\n\n";
    $json_response   = $callback.'('.$json_response.');';
} else {
    # Header for access via browser, curl, etc.
    print "Content-type: application/json\n\n";
}

print $json_response;
