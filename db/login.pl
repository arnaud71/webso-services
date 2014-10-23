#!/usr/bin/perl
######################################################################
# db/login.pl
# 
# verify login's user to connect on webso
#
# inputs:
#	username and password or token and token timeout
#
# Contributors:
#   - Salah Zenati : 18/04/2014
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
use Crypt::Bcrypt::Easy;
use Data::GUID;

my $q       = CGI->new;
my $cgi     = $q->Vars;

#Lifetime of a token in Day (D*sec in day)
my $life = 7*86400;

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
	my $id;
	my $db_jeton;
	my $db_username;
	my $db_email;
#	my $db_compteur_sessions;
	my $db_role;
	my $db_token;
	my $db_token_timeout;
	my $db_creation_dt;
	my $db_updating_dt;

	my $query 	= q{};
	my $db_user = $$cgi{'user_s'};
	my $pass 	= $$cgi{'password_s'};
	my $db_password = md5_hex($pass);
	my $db_bcrypt	= bcrypt->crypt($pass);

	my $lengthUsername = length($db_user);
	my $lengthPassword = length($pass);

	$query 	= 'q='.'user_s:'.$db_user.' AND password_s:'.$db_password;

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

	my $query_encoded_1;
	my $query_encoded_2;
	my $response_1;
	my $response_2;
	my $response_3;
	my $response_4;
	
        $query_encoded_1 = uri_encode(
            "collection1/select?"
	    .$query
            .'&wt=json&indent=true');
				
	$response_1 = $ua->get($cfg->param('ws_db').$query_encoded_1);

	#$perl_response{'error'} = $cfg->param('ws_db').$query_encoded_1;

	my $response_text = $json->decode($response_1->decoded_content);

	if($lengthUsername >= 6 and $lengthUsername <= 20 and $lengthPassword >= 6 and $lengthPassword <= 20){
			if ($response_1->is_success) {
				if($response_text->{response}->{numFound} eq 1){

					$query_encoded_2 = uri_encode(
					"collection1/select?"
					.$query. ' AND jeton_s:false'
					.'&wt=json&indent=true');
								
					$response_2 = $ua->get($cfg->param('ws_db').$query_encoded_1);
					my $response_text = $json->decode($response_2->decoded_content);				

					if ($response_2->is_success) {
						#if($response_text->{response}->{numFound} eq 1){
							## delete callback
							delete $$cgi{'callback'};

							#Prepare change.pl request to avoid redundant code
							$id	       = $response_text->{response}->{docs}[0]->{"id"};
							$db_token  = $response_text->{response}->{docs}[0]->{"token_s"};
							$db_token_timeout  = $response_text->{response}->{docs}[0]->{"token_timeout_l"};
							$db_username	= $response_text->{response}->{docs}[0]->{"user_s"};
							$db_role	 	= $response_text->{response}->{docs}[0]->{"role_s"};
							# $db_compteur_sessions = $response_text->{response}->{docs}[0]->{"compteur_sessions_s"};

							my $tm = time;
							if(!$db_token_timeout || $db_token_timeout <= $tm){
								my $token = Data::GUID->new;
								$db_token = md5_hex($token->as_string.$tm);
								$db_token_timeout = $tm+$life;
							}
							my $data = '{"id":"'.$id.'", "jeton_s": "true", "token_s":"'.$db_token.'", "token_timeout_l":"'.$db_token_timeout.'"}';
							#$data{"compteur_sessions_s"} 	= $db_compteur_sessions + 1;

							my $req = HTTP::Request->new(
								POST => $cfg->param('webso_services').'/db/change.pl'
							);

							$req->content_type('application/json');
							$req->content($data);

								$response_4 = $ua->request($req);
								if ($response_4->is_success) {
									$perl_response{success} = $json->decode( $response_4->decoded_content);
									$perl_response{username} = $db_username;
									$perl_response{role} = $db_role;
									$perl_response{token} = $db_token;
									$perl_response{token_timeout} = $db_token_timeout;
								}else {
									$perl_response{'error'} = "sources server or service: ".$response_4->code;
									if ($deb_mod) {
										$perl_response{'debug_msg'} = $response_4->message;
									}
								}
=pod
								}else{
									$perl_response{'error'} = 'vous êtes déjà connecté ';
								}		

							}else{
								$perl_response{'error'} = "sources server or service: $json_text ".$response_3->code;
								if ($deb_mod) {
										$perl_response{'debug_msg'} = $response_3->message;
								}
							}
						}else{
							$perl_response{'error'} = 'vous êtes déjà connecté ';
						}
=cut
					}else{
						$perl_response{'error'} = "sources server or service: ".$response_2->code;
						if ($deb_mod) {
						    $perl_response{'debug_msg'} = $response_2->message;
						}
					}
				}else{
				    $perl_response{'error'} = ' nom d\'utilisateur et/ou mot de passe incorrect(s)';
				}
		        }else {
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

my $json_response = $json->pretty->encode(\%perl_response);

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

