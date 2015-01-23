#!/usr/bin/perl
######################################################################
# change
#
# atomic update of solr object
#
# inputs:
#     id : of the solr object (required)
#     token & token timeout : ref to the user that make the request 
#                             to check if he got a right to do it
#     + any fields
#
# notes: do an explicit commit
#
# TODO ENABLE SECURITY !!
#
# Contributors:
#   - Arnaud Gaudinat : 11/08/2014
#   - Clément MILLET  : 16/01/2015
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

    #If script call via POST
    if($q->param('POSTDATA')){
        my @var = $json->decode($$cgi{'POSTDATA'});
        $cgi = $var[0];
    }

    if ($$cgi{'id'}) {
        foreach my $k (keys %$cgi) {
            if ($k ne 'callback') {
                if ($k eq 'id') {
                    $query .= '"id":"'.$$cgi{$k}.'",';
                }
                elsif($k eq 'password_s'){
                    $query .= '"'.$k.'":{"set":"'.md5_hex($$cgi{$k}).'"},';
                }
                elsif($k eq 'password_hash'){
                    $query .= '"password_s":{"set":"'.$$cgi{$k}.'"},';
                }
                elsif($k eq 'source_id_ss'){
                    my $t='';
                    my @test = split(',', $$cgi{$k});
                    foreach my $ve (@test){
                        $t .= '"'.$ve.'",';
                    }
                    #Remove the last coma to prevent error
                    chop($t);
                    $query .= '"source_id_ss":{"set":['.$t.']},';
                }
                elsif($k eq 'tags_ss'){
                    my $t='';
                    my @test = split(',', $$cgi{$k});
                    foreach my $ve (@test){
                        #Trim spaces before and after
                        $ve =~ s/^\s+|\s+$//g;
                        $t .= '"'.$ve.'",';
                    }
                    #Remove the last coma to prevent error
                    chop($t);
                    $query .= '"tags_ss":{"set":['.$t.']},';
                }
                else{
                    $query .= '"'.$k.'":{"set":"'.$$cgi{$k}.'"},';
                }
            }
        }
        $query .= '"updating_dt":{"set":"'.$str_now.'"}';
        #$query .= '"revision":{"inc":1}'."\n";
        $json_text = '{'.$query.'}';
        print $json_text;
    }
    else{
        push @{$perl_response{'error'}},'atomic change ID is missing';
    }
    # if(!$$cgi{'token'} || !$$cgi{'token_timeout'}) {
    #     push @{$perl_response{'error'}},'No user identification';
    # }


    # if ($q->param('callback')) {
    #     $callback    = $q->param('callback');
    # }
    if ($$cgi{'callback'}) {
        $callback    = $$cgi{'callback'};
    }


    if (!(exists $perl_response{'error'})) {

         # init user_agent
        my $ua = LWP::UserAgent->new;
        $ua->timeout(10);
        # $ua->env_proxy;

        # my $response_1 = $ua->get($cfg->param('webso_services').
        #     uri_encode('/db/get.pl?'.
        #         $cfg->param('db_type').'='.$cfg->param('t_user').
        #         '&'.$cfg->param('db_token').'='.$$cgi{'token'}.
        #         '&'.$cfg->param('db_token_timeout').'='.$$cgi{'token_timeout'}));

        # if ($response_1->is_success) {
        #     $response_text_1 = $json->decode($response_1->decoded_content);
        #     if($response_text_1->{success}->{response}->{numFound} eq 1){
        #         #check if the user is the owner of what he update
        #         my $response_2 = $ua->get($cfg->param('webso_services').
        #             uri_encode('/db/get.pl?'.
        #                 $cfg->param('id').'='.$$cgi{'id'}.
        #                 '&'.$cfg->param('db_user').':'.$response_text_1->{success}->{response}->{docs}[0]->{id}));
        #             ));
        #         if ($response_2->is_success) {
        #             my $response_text_2 = $json->decode($response_2->decoded_content);
        #             if($response_text_2->{success}->{response}->{numFound} eq 1){
        #                 #Make the update
        #                 my $req = HTTP::Request->new(
        #                     POST => $cfg->param('ws_db').'update?commit=true'
        #                 );
        #                 $req->content_type('application/json');
        #                 $req->content('['.$json_text.']');

        #                 my $res = $ua->request($req);


        #                 if ($res->is_success) {
        #                     $perl_response{success} = $json->decode($res->content);
        #                 }
        #                 else {
        #                     $perl_response{'error'} = 'sources server or service: '.$res->code;
        #                     if ($deb_mod) {
        #                         $perl_response{'debug_msg'} = $res->message;
        #                     }
        #                 }
        #             }
        #             else{
        #                 $perl_response{error} = "You don't have the rights to download this file.";
        #             }
        #         }else{
        #             $perl_response{error} = "sources server or service2: ".$response_2->code;
        #             if ($deb_mod) {
        #                 $perl_response{debug_msg} = $response_2->message;
        #             }
        #         }
        #     }else{
        #         $perl_response{error} = "No account available";
        #     }
        # }else{
        #     $perl_response{error} = "sources server or service1: ".$response_1->code;
        #     if ($deb_mod) {
        #         $perl_response{debug_msg} = $response_1->message;
        #     }
        # }

        my $req = HTTP::Request->new(
            POST => $cfg->param('ws_db').'update?commit=true'
        );
        $req->content_type('application/json');
        $req->content('['.$json_text.']');

        my $res = $ua->request($req);


        if ($res->is_success) {
            $perl_response{success} = $json->decode($res->content);
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
    print 'Access-Control-Allow-Methods: GET, POST, OPTIONS'."\n";
    print "Content-type: application/javascript; charset=utf-8\n\n";
    $json_response   = $callback.'('.$json_response.');';
} else {
    # Header for access via browser, curl, etc.
    print "Content-type: application/json\n\n";
}

print $json_response;
