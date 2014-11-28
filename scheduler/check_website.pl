#!/usr/bin/perl
#######################################
# check_crawl.pl
#
# TODO send webpage data
###########################################

use strict;
use LWP::UserAgent;
use Config::Simple;
use URI::Encode qw(uri_encode uri_decode);
use JSON;
use Data::Dump qw(dd);
use IO::Socket::INET;
use Digest::MD5::File qw(dir_md5_hex file_md5_hex url_md5_hex);
use Log::Log4perl qw(:easy);
use Time::localtime;
use lib '..';
use Tools;
use FindBin qw($Bin);
use LWP::Simple;


my $json    = JSON->new->allow_nonref;

my $cfg                     = new Config::Simple("$Bin/../webso.cfg");
my $webso_services          = $cfg->param('webso_services');
my $db_type                 = $cfg->param('db_type');
my $deb_mod                 = $cfg->param('debug');


#my $test_data ='<html><body><h1>titre document</h1> et le reste <body></html>';
#extract_tika_content(\$test_data);
#exit;

# init user_agent
my $ua = LWP::UserAgent->new;
$ua->timeout(1000);
#$ua->env_proxy;


my $params = '?'.$db_type.'=source&source_type_s=HTTP';
my $response = $ua->get($webso_services.'db/get.pl'.$params);

my $url    = '';
my $id     = '';
my $user   = '';
my $title  = '';
my $digest = '';
my $query  = '';
my $req    = '';
my $contenu = '';
my $response_3 = '';
my $response_text = '';
my %perl_response = ();
my $query_encoded_1 = '';


if ($response->is_success) {
    my $error_msg = q{};
    my $r_json = $json->decode($response->content);
    # check all services
    my $i = 0;
    while ($r_json->{success}{response}{docs}[$i]) {
        #system("wget -P/tmp/inelio $r_json->{success}{response}{docs}[$i]{url_s} -O alpha.html");
        $url   = $r_json->{success}{response}{docs}[$i]{url_s};
        $id    = $r_json->{success}{response}{docs}[$i]{id};
        $user  = $r_json->{success}{response}{docs}[$i]{user_s};
        $title = $r_json->{success}{response}{docs}[$i]{title_t};

        my $md5 = Digest::MD5->new;
        $md5->addurl($url);
        $digest = $md5->hexdigest;

        $contenu = get($url);#, $contenu);
        $contenu='Test';

        $query  = 'q='.'type_s:document AND source_id_ss:'.$id;
        $query_encoded_1 = uri_encode(
            "collection1/select?"
            .$query
            .'&wt=json&indent=true');
        $response = $ua->get($cfg->param('ws_db').$query_encoded_1);
        $response_text = $json->decode($response->decoded_content);
        #die $response->content;
        if ($response->is_success) {
            if($response_text->{response}->{numFound} eq 1){
                if($response_text->{response}->{docs}->[0]->{md5sum_s} ne $digest){

                    $req = HTTP::Request->new(
                        #POST => $cfg->param('webso_services').'/db/put.pl'
                        GET => $cfg->param('webso_services').'/db/put.pl?type_s=document&validated_b=false&read_b=false&source_id_ss='.$id.'&url_s='.$url.'&title_t='.$title.'&md5sum_s='.$digest.'&content_t='.$contenu
                    );

                    $req->content_type('application/json');
                    #$req->content('[{"type_s": "document", "validated_b": false, "read_b": false, "source_id_ss": "'.$id.'", "url_s": "'.$url.'", "md5sum_s": "'.$digest.'", "content_t":"'.$contenu.'"}]')

                    $response_3 = $ua->request($req);

                    if ($response_3->is_success) {
                        $perl_response{success} = $json->decode($response_3->content);
                    }else{
                        $perl_response{'error'} = "sources server or service: ".$response_3->code;
                        if ($deb_mod) {
                                $perl_response{'debug_msg'} = $response_3->message;
                        }
                    }
                }
            }
            else{
                $req = HTTP::Request->new(
                    GET => $cfg->param('webso_services').'/db/put.pl?type_s=document&validated_b=false&read_b=false&source_id_ss='.$id.'&url_s='.$url.'&title_t='.$title.'&md5sum_s='.$digest.'&content_t='.$contenu
                    #POST => $cfg->param('ws_db').'update'
                );  

                $req->content_type('application/json');
                #$req->content('[{"type_s": "document", "validated_b": false, "read_b": false, "source_id_ss": "'.$id.'", "url_s": "'.$url.'", "md5sum_s": "'.$digest.'"}]'); #, "content_t":"'.$contenu.'"}');
                #$req->content('type_s=document&validated_b=false&read_b=false&source_id_ss="'.$id.'"&url_s="'.$url.'"&md5sum_s="'.$digest.'"&content_t="'.$contenu.'"');

                $response_3 = $ua->request($req);

                if ($response_3->is_success) {
                    $perl_response{success} = $json->decode($response_3->content);
                }else{
                    $perl_response{'error'} = "sources server or service3: ".$response_3->code;
                    if ($deb_mod) {
                            $perl_response{'debug_msg'} = $response_3->message;
                    }
                }
            }
        }
        $i++;
        #exit;
    }
    #if ($error_msg) {
        #$$r_json_rss{error} = $error_msg;
    #}
}
else {
     die $response->status_line;
}

my $json_response   = $json->pretty->encode(\%perl_response);

print $json_response;
