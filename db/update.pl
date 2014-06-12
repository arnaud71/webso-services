#!/usr/bin/perl
######################################################################
# db/update.pl
# 
# update :
#	- informations of user 
#	- informations of widget
# inputs:
#	informations of user or widget
#
# Contributors:
#   - Salah Zenati : 02/05/2014
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

my $q       = CGI->new;
my $cgi     = $q->Vars;
# prepare the JSON msg
my $json    = JSON->new->allow_nonref;
my $callback = q{};
my %perl_response = ();
# print json header
print $q->header('application/json');
# reading the conf file
my $cfg     = new Config::Simple('../webso.cfg');

if (Config::Simple->error()) {
    $perl_response{'debug_msg'} = Config::Simple->error();
    push @{$perl_response{'error'}},'Config file error';
}
else {
    my $tm = localtime;
    my $str_now = sprintf("%04d-%02d-%02d".'T'. "%02d:%02d:%02d".'Z', $tm->year+1900,($tm->mon)+1, $tm->mday, $tm->hour, $tm->min, $tm->sec);
	my $deb_mod 		= $cfg->param('debug');
	my $id				= $cfg->param('id');
	my $role			= $cfg->param('db_role');
	my $type 			= $cfg->param('db_type');
	my $widgetTitle 	= $cfg->param('db_widgetTitle');
	my $db_id 			= $$cgi{$id};
	my $db_role 		= $$cgi{$role};
	my $db_widgetTitle 	= $$cgi{$widgetTitle};
	my $db_type 		= $$cgi{$type};
	my $query 			= q{};
	$query 	= 'q='.'id:'.$db_id;
	if ($q->param('callback')) {
		$callback    = $q->param('callback');
	}

	if($db_type eq 'user'){
		#my $db_compteur_sessions;
		my $db_jeton;
		my $db_password;
		my $db_user;
		my $db_creation_dt;
		my $db_updating_dt;
		if (!(exists $perl_response{'error'})) {
			# concatenate query and response
			%perl_response = (%perl_response,%$cgi);
			# init user_agent
			my $ua = LWP::UserAgent->new;
			$ua->timeout(10);
			$ua->env_proxy;

			my $query_encoded = uri_encode(
			"collection1/select?"
			.$query
			.'&wt=json&indent=true');
				
			my $response_1 = $ua->get($cfg->param('ws_db').$query_encoded);
			my $response_text = $json->decode($response_1->decoded_content);				

			if ($response_1->is_success) {
				if($response_text->{response}->{numFound} eq 1){
					## delete callback
					delete $$cgi{'callback'};  		
					#$db_compteur_sessions 	= $response_text->{response}->{docs}[0]->{"compteur_sessions_s"};
					$db_jeton 			= $response_text->{response}->{docs}[0]->{"jeton_s"};
					$db_password 		= $response_text->{response}->{docs}[0]->{"password_s"};
					$db_user	 		= $response_text->{response}->{docs}[0]->{"user_s"};
					$db_creation_dt	 	= $response_text->{response}->{docs}[0]->{"creation_dt"};
					#faire un POST sur le "ROLE" sur le user en cours
					$$cgi{"id"} 			= $db_id;
					$$cgi{"user_s"} 		= $db_user;
					$$cgi{"password_s"} 	= $db_password;
					$$cgi{"role_s"} 		= $db_role;
					$$cgi{"jeton_s"} 		= $db_jeton;
					#$$cgi{"compteur_sessions_s"} = $db_compteur_sessions;
					$$cgi{"type_s"} 		= $db_type;
					$$cgi{"creation_dt"} 	= $db_creation_dt;
					$$cgi{"updating_dt"} 	= $str_now;
					my $json_text   = $json->pretty->encode($cgi);

					my $req = HTTP::Request->new(
							POST => $cfg->param('ws_db').'update'
					);
					$req->content_type('application/json');
					$req->content('['.$json_text.']');

					my $response_2 = $ua->request($req);
					if ($response_2->is_success) {
						$perl_response{success} = $json->decode( $response_2->decoded_content);
					}else {
						$perl_response{'error'} = "sources server or service: ".$response_2->code;
						if ($deb_mod) {
							$perl_response{'debug_msg'} = $response_2->message;
						}
					}
				}else{
					$perl_response{'error'} = 'utilisateur non existant ';
				}
			}else{
				$perl_response{'error'} = "sources server or service: ".$response_1->code;
				if ($deb_mod) {
				    $perl_response{'debug_msg'} = $response_1->message;
				}
			}
		}
	}else{
		if($db_type eq 'widget'){
			my $db_userWidgetId;
			my $db_widgetEnable;
			my $db_widgetName;
			my $db_widgetWeight;
			my $db_creation_dt;
			my $db_updating_dt;
			if (!(exists $perl_response{'error'})) {
				# concatenate query and response
				%perl_response = (%perl_response,%$cgi);
				# init user_agent
				my $ua = LWP::UserAgent->new;
				$ua->timeout(10);
				$ua->env_proxy;

				my $query_encoded = uri_encode(
				"collection1/select?"
				.$query
				.'&wt=json&indent=true');
					
				my $response_1 = $ua->get($cfg->param('ws_db').$query_encoded);
				my $response_text = $json->decode($response_1->decoded_content);				

				if ($response_1->is_success) {
					if($response_text->{response}->{numFound} eq 1){
						## delete callback
						delete $$cgi{'callback'};
						$db_userWidgetId 		= $response_text->{response}->{docs}[0]->{"userWidgetId_s"};
						$db_widgetEnable 		= $response_text->{response}->{docs}[0]->{"widgetEnable_s"};
						$db_widgetName	 		= $response_text->{response}->{docs}[0]->{"widgetName_s"};
						$db_widgetWeight	 	= $response_text->{response}->{docs}[0]->{"widgetWeight_dt"};
						$db_creation_dt	 		= $response_text->{response}->{docs}[0]->{"creation_dt"};
						#faire un POST sur le "ROLE" sur le user en cours
						$$cgi{"id"} 				= $db_id;
						$$cgi{"userWidgetId_s"} 	= $db_userWidgetId;
						$$cgi{"widgetEnable_s"} 	= $db_widgetEnable;
						$$cgi{"widgetName_s"} 		= $db_widgetName;
						$$cgi{"widgetWeight_s"} 	= $db_widgetWeight;
						$$cgi{"creation_dt"} 		= $db_creation_dt;
						$$cgi{"type_s"} 			= $db_type;
						$$cgi{"widgetTitle_s"} 		= $db_widgetTitle;
						$$cgi{"updating_dt"} 		= $str_now;
						my $json_text   = $json->pretty->encode($cgi);

						my $req = HTTP::Request->new(
								POST => $cfg->param('ws_db').'update'
						);
						$req->content_type('application/json');
						$req->content('['.$json_text.']');

						my $response_2 = $ua->request($req);
						if ($response_2->is_success) {
							$perl_response{success} = $json->decode( $response_2->decoded_content);
						}else {
							$perl_response{'error'} = "sources server or service: ".$response_2->code;
							$perl_response{'errorERROR'} = $$cgi{"widgetTitle_s"};

							if ($deb_mod) {
								$perl_response{'debug_msg'} = $response_2->message;
							}
						}
					}else{
						$perl_response{'error'} = 'widget non existant ';
					}
				}else{
					$perl_response{'error'} = "sources server or service: ".$response_1->code;
					if ($deb_mod) {
					    $perl_response{'debug_msg'} = $response_1->message;
					}
				}
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
