#!/usr/bin/perl
######################################################################
# db/logout.json
# 
# modify fields "jeton" and "compteur_sessions" in webso's user
#
# inputs:
#	username
# TODO input tokens instead of username
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
	my $id;
	my $db_jeton;
	my $db_email;
#	my $db_compteur_sessions;
	my $db_role;
	my $query 	= q{};
	my $db_user 	= $$cgi{'user_s'};
	my $db_username;
	# my $pass 	= $$cgi{'password_s'};
	my $db_password	;#= md5_hex($pass);
	my $db_token;
	my $db_token_timeout;
	my $db_creation_dt;
	my $db_updating_dt;

	#$query 	= 'q='.'user_s:'.$db_user. ' AND password_s:'.$db_password;
	$query 	= 'q='.'user_s:'.$db_user.' AND type_s:user';

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
		my $response_1;
		my $response_2;

		$query_encoded_1 = uri_encode(
		    "collection1/select?"
		    .$query
		    .'&wt=json&indent=true');
				
		$response_1 = $ua->get($cfg->param('ws_db').$query_encoded_1);
		my $response_text = $json->decode($response_1->decoded_content);

		if ($response_1->is_success) {
			if($response_text->{response}->{numFound} eq 1){
				## delete callback
				delete $$cgi{'callback'};

				$id			= $response_text->{response}->{docs}[0]->{"id"};   		
				$db_jeton 		= $response_text->{response}->{docs}[0]->{"jeton_s"};
				$db_username	= $response_text->{response}->{docs}[0]->{"user_s"};
				$db_email		= $response_text->{response}->{docs}[0]->{"email_s"};
				$db_password	= $response_text->{response}->{docs}[0]->{"password_s"};
				# $db_compteur_sessions 	= $response_text->{response}->{docs}[0]->{"compteur_sessions_s"};
				$db_role	 	= $response_text->{response}->{docs}[0]->{"role_s"};
				$db_token		= $response_text->{response}->{docs}[0]->{"token_s"};
				$db_token_timeout	= $response_text->{response}->{docs}[0]->{"token_timeout_dt"};
				$db_creation_dt	 	= $response_text->{response}->{docs}[0]->{"creation_dt"};
				$db_updating_dt	 	= $response_text->{response}->{docs}[0]->{"updating_dt"};
					
				# - faire un POST sur le "JETON" sur le user en cours
				#	en le remettant à "FALSE" et remettre le compteur de sessions a 0
				$$cgi{"id"}                 = $id;
				$$cgi{"user_s"}             = $db_username;
				$$cgi{"password_s"}         = $db_password;
				$$cgi{"email_s"}			= $db_email;
				$$cgi{"role_s"}             = $db_role;
				$$cgi{"jeton_s"}            = 'false';
				$$cgi{"token_s"}			= $db_token;
				$$cgi{"token_timeout_dt"}	= $db_token_timeout;
				# $$cgi{"compteur_sessions_s"} = $db_compteur_sessions + 1;
				$$cgi{"type_s"}             = 'user';
				$$cgi{"creation_dt"}        = $db_creation_dt;
				$$cgi{"updating_dt"}        = $db_updating_dt;

				my $json_text   = $json->pretty->encode($cgi);

				my $req = HTTP::Request->new(
						POST => $cfg->param('ws_db').'update'
				);
				$req->content_type('application/json');
				$req->content('['.$json_text.']');

				$response_2 = $ua->request($req);
				if ($response_2->is_success # and $$cgi{"compteur_sessions_s"} eq 0 
																		and $$cgi{"jeton_s"} eq 'false') {
					$perl_response{success} = $json->decode( $response_2->decoded_content);
				}else {
					$perl_response{'error'} = "sources server or service: ".$response_2->code;
					if ($deb_mod) {
						$perl_response{'debug_msg'} = $response_2->message;
					}
				}
			}else{
			    $perl_response{'error'} = ' erreur de déconnexion inconnue ';			
			}
		}else{
		    $perl_response{'error'} = "sources server or service ".$response_1->code;
		    if ($deb_mod) {
		        $perl_response{'debug_msg'} = $response_1->message;
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
