#!/usr/bin/perl
######################################################################
# send.pl
# 
# Send email with shared data
#
# inputs:
#   many
#
# Contributors:
#   - Clement MILLET : 10/12/2014
######################################################################

use strict;
use CGI;
use JSON;
use lib "..";
use LWP::UserAgent;
use Config::Simple;
use Digest::MD5 qw(md5 md5_hex md5_base64);
use URI::Encode qw(uri_encode uri_decode);
use MIME::Lite;
use FindBin qw($Bin);

my $q = CGI->new;
my $cgi = $q->Vars;

# prepare the JSON msg
my $json    = JSON->new->allow_nonref;

my $callback = q{};

my %perl_response = ();

# reading the conf file
my $cfg   = new Config::Simple('./webso.cfg');
my $mail  = '';
my $token = '';
my $token_timout = '';
my $call_type = '';
my $message_data= '';
my $message_headder = '<!DOCTYPE html>
<html>
<head>
    <meta http-equiv="content-Type" content="text/html" charset="UTF-8" />
    <meta http-equiv="content-language" content="french" />
</head>
<body width="900px"; align="center">
<div width="900px" style="width: 900px; margin: auto;">
<table width="900px" align="center" style="width: 900px; margin: auto;">
<tr>
    <td>
        <header style="margin:20px 0;">
        <img src="http://inelio.fr/images/logo.png" alt="Logo I+1" style="width:153px; height:157px;"/>
    </td>
    <td colspan=3>
        <h3 style="text-align: center; ">Inélio, votre plate-forme de veille intuitive et collaborative</h3>
    </td>
</tr>';
my $message_footer = '<tr>
    <td colspan=2>
        <p style="margin-top: 30px; text-align: center; ">Cordialement,<br>
        L’équipe d’Inélio</p>
    </td>
    <td colspan=2>
        <footer style="margin: 20px 30px; text-align: right; ">
        <p>Mail : contact@inelio.fr<br>
        Tel : +33 (0)6 75 68 41 04</p>
    </footer>
    </td>
</tr>
</table>
</body>
</html>';

if (Config::Simple->error()) {
    push @{$perl_response{'error'}},'Config file error';
    $perl_response{'debug_msg'} = Config::Simple->error();
}
else {
    my $deb_mod = $cfg->param('debug');
    my $query   = q{};

    if ($q->param('token')) {
        $call_type = 'GET';
        foreach my $k (keys %$cgi) {
            if ( $k eq 'callback' ) { $callback = $$cgi{'callback'}; }
            elsif ( $k eq 'mail' ) { $mail = $$cgi{'mail'}; }
            elsif ( $k eq 'token' ) { $token = $$cgi{'token'}; }
            elsif ( $k eq 'token_timeout' ) { $token_timout = $$cgi{'token_timeout'}; }
            elsif ( $k eq 'url_s' ) { $message_data .= '<tr><td></td> <td>lien</td> <td><a href='.$$cgi{$k}.'>'.$$cgi{$k}.'</a></td> <td></td></tr>'; }
            else {
                $message_data .= '<tr><td></td> <td>'.$k.'</td> <td>'.$$cgi{$k}.'</td> <td></td></tr>';
            }
        }
    }
    else{
        if($q->param('POSTDATA')){
            $call_type = "POST";
            my @var = $json->decode($$cgi{'POSTDATA'});

            foreach my $k (keys $var[0]) {
                if ( $k eq 'callback' ) { $callback = $var[0]{'callback'}; }
                elsif ( $k eq 'mail' ) { $mail = $$cgi{'mail'}; }
                elsif ( $k eq 'token' ) { $token = $var[0]{'token'}; }
                elsif ( $k eq 'token_timeout' ) { $token_timout = $var[0]{'token_timeout'}; }
                elsif ( $k eq 'url_s' ) { $message_data .= '<tr><td></td> <td>lien</td> <td><a href='.$$cgi{$k}.'>'.$$cgi{$k}.'</a></td> <td></td></tr>'; }
                else {
                    $message_data .= '<tr><td></td> <td>'.$k.'</td> <td>'.$var[0]{$k}.'</td> <td></td></tr>';
                }
            }
        }
        else{
            push @{$perl_response{'error'}},'Method not allowed or insuffisiant data';
        }
    }

    if($mail eq '') { push @{$perl_response{'error'}},'Merci de saisir un mail de destination'; }
    if($token eq '') { push @{$perl_response{'error'}},'Error system 1'; }
    if($token_timout eq '') { push @{$perl_response{'error'}},'Error system 2'; }

    $query  = 'q='.'token_s:'.$token.' AND token_timeout_l:'.$token_timout;

    if (!(exists $perl_response{'error'})) {
        # concatenate query and response
        %perl_response = (%perl_response,%$cgi);

        # init user_agent
        my $ua = LWP::UserAgent->new;
        $ua->timeout(10);
        $ua->env_proxy;

        my $query_encoded_1;
        my $response_1;
    
        $query_encoded_1 = uri_encode(
            "collection1/select?"
            .$query
            .'&wt=json&indent=true');
                
        $response_1 = $ua->get($cfg->param('ws_db').$query_encoded_1);

        my $response_text = $json->decode($response_1->decoded_content);

        if ($response_1->is_success) {
            if($response_text->{response}->{numFound} eq 1){
                # $perl_response{'res'} = $response_text->{response};
                if(($response_text->{response}->{docs}[0]->{"jeton_s"} eq 'true') && ($token_timout >= time)){
                    my $text = '<tr>
                            <td width="160px">
                            </td>
                            <td colspan=2>
                                <h3>'.$response_text->{response}->{docs}[0]->{user_s}.' a partagé une information avec vous :</h3>
                            </td>
                            <td width="160px">
                            </td>
                        </tr>';
                    my $msg = MIME::Lite->new(
                        From     => 'no-reply@inelio.fr',
                        To       => $mail,
                        Cc       => '',
                        Subject  => $response_text->{response}->{docs}[0]->{user_s}.' vous partage une information',
                        Data     => $message_headder.$text.$message_data.$message_footer
                    );
                    # $perl_response{'mail'} = $message_headder.$text.$message_data;
                    $msg->attr("content-type" => "text/html");
                    #Only usable when a postfix server is running.
                    $msg->send;

                }else{
                    $perl_response{'error'} = 'Un problème lié a votre compte est survenu essayé de vous reonnecter à la plate-forme';
                }
            }else{
                $perl_response{'error'} = 'Prblème de compte surnuméraire';
            }
        }else {
            $perl_response{'error'} = "sources server or service: ".$response_1->code;
            if ($deb_mod) {
                $perl_response{'debug_msg'} = $response_1->message;
            }
        }
    }
    # else{
    #     $perl_response{'errors'} = "Merci de remplir les champs";
    # }
}

my $json_response = $json->pretty->encode(\%perl_response);

if ($callback) { 
    print 'Access-Control-Allow-Origin: *';
    print 'Access-Control-Allow-Methods: POST, OPTIONS';
    print "Content-type: application/javascript; charset=utf-8\n\n";
    $json_response  = $callback.'('.$json_response.');';
} else { 
    # Header for access via browser, curl, etc.
    print 'Access-Control-Allow-Methods: POST, OPTIONS';
    print "Content-type: application/json\n\n";
} 

print $json_response;