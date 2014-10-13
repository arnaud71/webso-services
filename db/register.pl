#!/usr/bin/perl
######################################################################
# db/register.pl
# 
# register a user on webso
#
# inputs:
#	username, password, email
#
# Contributors:
#   - Salah Zenati : 10/06/2014
#   - Clement MILLET : 06/10/2014
######################################################################

use strict;
use CGI;
use JSON;
use lib "..";
use LWP::UserAgent;
use Config::Simple;
use Digest::MD5 qw(md5 md5_hex md5_base64);
use URI::Encode qw(uri_encode uri_decode);
use Time::localtime;
use Crypt::Bcrypt::Easy;

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
	my $db_jeton;
	my $db_creation_date        = $cfg->param('db_creation_date');
	my $db_updating_date        = $cfg->param('db_updating_date');
	my $query 			= q{};
    my $tm 				= localtime;
	my $str_now 		= sprintf("%04d-%02d-%02d".'T'. "%02d:%02d:%02d".'Z', $tm->year+1900,($tm->mon)+1, $tm->mday, $tm->hour, $tm->min, $tm->sec);
	my $db_user 		= $$cgi{'user_s'};
	my $pass 			= $$cgi{'password_s'};
	my $db_role 		= $$cgi{'role_s'};
	my $db_password		= md5_hex($pass);
	#Change to bcrypt for november release
	#my $db_password		= bcrypt->crypt( $pass );
	my $db_email		= $$cgi{'email_s'};
	my $id 				= 'u_'.md5_hex($db_user.$db_password);
	my $lengthUsername 	= length($db_user);
	my $lengthPassword 	= length($pass);

	$query 	= 'q='.'user_s:'.$db_user. ' AND type_s:user';
	
	if ($q->param('callback')) {
		$callback    = $q->param('callback');
	}

    if (!(exists $perl_response{'error'})) {
        # concatenate query and response
        %perl_response = (%perl_response,%$cgi);


    # init user_agent
    my $ua = LWP::UserAgent->new;
    $ua->timeout(10);
    $ua->env_proxy;

	my $query_encoded;
	my $response_1;
	my $response_2;

    $query_encoded = uri_encode(
        "collection1/select?"
    .$query
        .'&wt=json&indent=true');

	if($lengthUsername >= 6 and $lengthUsername <= 20 and $lengthPassword >= 6 and $lengthPassword <= 20){
			$response_1 = $ua->get($cfg->param('ws_db').$query_encoded);
			my $response_text = $json->decode($response_1->decoded_content);

			if ($response_1->is_success) {
				if($response_text->{response}->{numFound} eq 0){
					## delete callback
					delete $$cgi{'callback'};
					# enregistrement de l'utilisateur
					$$cgi{"id"}                 = $id;
					$$cgi{"user_s"}             = $db_user;
					$$cgi{"password_s"}         = $db_password;
					$$cgi{"role_s"}             = $db_role;
					$$cgi{"email_s"}			= $db_email;
					$$cgi{"jeton_s"}            = 'false';
					$$cgi{"type_s"}            	= 'user';
				    $$cgi{$db_creation_date} 	= $str_now;
				    $$cgi{$db_updating_date} 	= $str_now;

					my $json_text   = $json->pretty->encode($cgi);

					my $req = HTTP::Request->new(
							POST => $cfg->param('ws_db').'update'
					);
					$req->content_type('application/json');
					$req->content('['.$json_text.']');

					$response_2 = $ua->request($req);
					if ($response_2->is_success) {
						$perl_response{success} = $json->decode($response_2->decoded_content);
					}else {
						$perl_response{'error'} = "sources server or service: ".$response_2->code;
						if ($deb_mod) {
							$perl_response{'debug_msg'} = $response_2->message;
						}
					}									
				}else{
					$perl_response{'error'} = 'Utilisateur déjà enrégistré';
				}
			}else{
	            $perl_response{'error'} = "sources server or service ".$response_1->code;
	            if ($deb_mod) {
	                $perl_response{'debug_msg'} = $response_1->message;
	            }
			}
		}else{
			$perl_response{'error'} = "Longueur du nom d'utilisateur et/ou du mot de passe doit/doivent être superieur(s) à 6 et inférieur(s) à 20 caractères";	
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