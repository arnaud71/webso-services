#!/usr/bin/perl
######################################################################
# db/reset.pl
# 
# Lost password :
# Save and send a new password to the user
#
# inputs:
#	username and mail
#
# Contributors:
#   - Clement MILLET : 16/10/2014
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
use String::Random;
use MIME::Lite;

my $q = CGI->new;
my $cgi = $q->Vars;

# prepare the JSON msg
my $json    = JSON->new->allow_nonref;

my $callback = q{};

my %perl_response = ();

# reading the conf file
my $cfg     = new Config::Simple('../webso.cfg');

if (Config::Simple->error()) {
	push @{$perl_response{'error'}},'Config file error';
	$perl_response{'debug_msg'} = Config::Simple->error();
}
else {
	my $deb_mod = $cfg->param('debug');
	my $id;
	my $query 	= q{};
	my $cgi_user = $q->param("user_s");
	my $cgi_mail = $q->param("email_s");
	my $cgi_callback = $q->param('callback');

	my $lengthUsername = length($cgi_user);
	my $lengthMail = length($cgi_mail);

	$query 	= 'q='.'user_s:'.$cgi_user.' AND email_s:'.$cgi_mail;

	if ($cgi_callback) {
		$callback = $cgi_callback;
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

		if($lengthUsername gt 0 and $lengthMail gt 0){
			if ($response_1->is_success) {
				if($response_text->{response}->{numFound} eq 1){

					$query_encoded_2 = uri_encode(
					"collection1/select?"
					.$query #. ' AND jeton_s:false'
					.'&wt=json&indent=true');
								
					$response_2 = $ua->get($cfg->param('ws_db').$query_encoded_1);
					my $response_text = $json->decode($response_2->decoded_content);				

					if ($response_2->is_success) {
						#if($response_text->{response}->{numFound} eq 1){
							## delete callback
							delete $$cgi{'callback'};

							$id	= $response_text->{response}->{docs}[0]->{"id"};
							my $name = $response_text->{response}->{docs}[0]->{"user_s"};
							my $mail = $response_text->{response}->{docs}[0]->{"email_s"};

							my $string_gen = String::Random->new;
							#Generate a 8 character password with 7 alphanumeric and 1 special character at the end.
							my $pass = $string_gen->randregex('\w{7}.');
							my $hash_pass = md5_hex($pass);
							#my $hash_pass = bcrypt->crypt($pass);

							my $req = HTTP::Request->new(
									POST => $cfg->param('webso_services').'/db/change.pl'
							);

							$req->content_type('application/json');
							$req->content('{"id":"'.$id.'", "password_s": "'.$hash_pass.'"}');
				
							$response_3 = $ua->request($req);

							if ($response_3->is_success) {

								$perl_response{success} = $json->decode($response_3->content);

								my $mess = '<!DOCTYPE html>
<html>
<head>
	<meta http-equiv="content-Type" content="text/html" charset="UTF-8" />
	<meta http-equiv="content-language" content="french" />
</head>
<body width="900px"; align="center">
<div width="900px" style="width: 900px; margin: auto;">
	<header style="margin:20px 0;">
		<img src="http://inelio.fr/images/logo.png" alt="Logo I+1" style="width:153px; height:157px;"/>
		<h3 style="float: right;">Inélio, votre plate-forme de veille intuitive et collaborative</h3>
	</header>
	<div style="margin: 30px;">
		<h3>Nouveau mot de passe</h3>
		<h4>Bonjour '.$name.'</h4>

		<p>Voici votre nouveau mot de passe :</p>
		<p style="margin-left:50px;">
			Login : '.$name.'<br>
			Mot de passe : '.$pass.'
		</p>
		<p>Nous vous conseillons de changer ce mot de passe rapidement.</p>

		<p style="margin-top: 30px">Cordialement,<br>
		L’équipe d’Inélio</p>
	</div>
	<footer style="margin: 20px 30px;">
		<p>Mail : contact@inelio.fr<br>
		Tel : +33 (0)6 75 68 41 04</p>
	</footer>
</div>
</body>
</html>';
								#"Voici votre nouveau mot de passe : ".$pass." nous vous conseillons de changer ce mot de passe rapidement.\n";

								my $msg = MIME::Lite->new(
									From     => 'no-reply@inelio.fr',
									To       => $mail,
									Cc       => '',
									Subject  => "Votre demande de mot de passe.",
									Data     => $mess
								);
								$msg->attr("content-type" => "text/html");
								#Only usable when a postfix server is running.
								$msg->send;

							}else{
								$perl_response{'error'} = "sources server or service: ".$response_3->code;
								if ($deb_mod) {
										$perl_response{'debug_msg'} = $response_3->message;
								}
							}
						# }else{	
						# 	$perl_response{'error'} = 'vous êtes déjà connecté ';
						# }
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
				$perl_response{'error'} = "sources server or service: ".$response_1->code;
				if ($deb_mod) {
					$perl_response{'debug_msg'} = $response_1->message;
				}
			}
		}else{
			$perl_response{'error'} = "Merci de remplir les champs";
		}
	}
}

my $json_response = $json->pretty->encode(\%perl_response);

if ($callback) { 
	print 'Access-Control-Allow-Origin: *';
	print 'Access-Control-Allow-Methods: POST, OPTIONS';
	print "Content-type: application/javascript; charset=utf-8\n\n";
	$json_response   = $callback.'('.$json_response.');';
} else { 
	# Header for access via browser, curl, etc.
	print 'Access-Control-Allow-Methods: POST, OPTIONS';
	print "Content-type: application/json\n\n";
} 

print $json_response;