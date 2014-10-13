#!/usr/bin/perl
######################################################################
# change
#
# atomic update of solr object
#
# inputs:
#     id : of the solr object (required)
#     + any fields
#
# notes: do an explicit commit
#
# Contributors:
#   - Arnaud Gaudinat : 11/08/2014
######################################################################

use strict;
use CGI;
use JSON;
use lib "..";
use LWP::UserAgent;
use Config::Simple;
use Crypt::Bcrypt::Easy;
use Digest::MD5 qw(md5 md5_hex md5_base64);
use URI::Encode qw(uri_encode uri_decode);
use Time::localtime;


# current date
my $tm = localtime;
my $str_now = sprintf("%04d-%02d-%02d".'T'. "%02d:%02d:%02d".'Z', $tm->year+1900,($tm->mon)+1, $tm->mday, $tm->hour, $tm->min, $tm->sec);

my $q       = CGI->new;
my $cgi     = $q->Vars;

# prepare the JSON msg
my $json    = JSON->new->allow_nonref;
my $json_text = q{};

my $callback = q{};

my %perl_response = (
    );

my $query = q{};


# reading the conf file
my $cfg     = new Config::Simple('../webso.cfg');

if (Config::Simple->error()) {
    push @{$perl_response{'error'}},'Config file error';
    $perl_response{'debug_msg'} = Config::Simple->error();
}
else {
    my $deb_mod = $cfg->param('debug');


    if ($q->param('id')) {
        foreach my $k (keys %$cgi) {
            if ($k ne 'callback') {
                if ($k eq 'id') {
                    $query .= '"id":"'.$$cgi{$k}.'",';
                }
                else {
                    if($k eq 'password_s'){
                        $query .= '"'.$k.'":{"set":"'.md5_hex($$cgi{$k}).'"},';
                    }
                    else{
                        $query .= '"'.$k.'":{"set":"'.$$cgi{$k}.'"},';
                    }
                }
            }
        }
        $query .= '"updating_dt":{"set":"'.$str_now.'"}';
        #$query .= '"revision":{"inc":1}'."\n";
        $json_text = '{'.$query.'}';
        print $json_text;

    }
    else {
        push @{$perl_response{'error'}},'atomic change ID is missing';
    }


    if ($q->param('callback')) {
        $callback    = $q->param('callback');
    }


    if (!(exists $perl_response{'error'})) {


         # init user_agent
        my $ua = LWP::UserAgent->new;
        $ua->timeout(10);
        $ua->env_proxy;

        my $req = HTTP::Request->new(
            POST => $cfg->param('ws_db').'update?commit=true'
        );
        $req->content_type('application/json');
        $req->content('['.$json_text.']');

        my $res = $ua->request($req);


        if ($res->is_success) {
            $perl_response{success} = $json->decode( $res->content);
        }
        else {
            $perl_response{'error'} = 'sources server or service: '.$res->code;
            if ($deb_mod) {
                $perl_response{'debug_msg'} = $res->message;
            }
        }
    }
}

my $json_response   = $json->pretty->encode(\%perl_response);

if ($callback) {
    print 'Access-Control-Allow-Origin: *';
    print 'Access-Control-Allow-Methods: GET';
    print "Content-type: application/javascript; charset=utf-8\n\n";
    $json_response   = $callback.'('.$json_response.');';
} else {
    # Header for access via browser, curl, etc.
    print "Content-type: application/json\n\n";
}

print $json_response;
