#!/usr/bin/perl -wT

######################################################################
# file/download.pl
# 
# download script to check if you are allowed to download the ressource you request
#
# inputs:
#   token
#   token_timeout
#   file
#
# Contributors:
#   - Clément MILLET : 21/01/2015
######################################################################

use strict;
use CGI;
use CGI::Carp qw(fatalsToBrowser);
use JSON;
use lib "..";
use LWP::UserAgent;
use Config::Simple;
use HTML::Restrict;
use URI::Encode qw(uri_encode uri_decode);

use FindBin qw($Bin);

# reading the conf file
my $cfg  = new Config::Simple("$Bin/../webso.cfg");

if (Config::Simple->error()) {
    # $perl_response{'debug_msg'} = Config::Simple->error();
    # push @{$perl_response{'error'}},'Config file error';
    exit(1);
}

# prepare the JSON msg
my $json    = JSON->new->allow_nonref;

my $q        = CGI->new;
my $cgi      = $q->Vars;
my $file     = '';
my $filename = '';
my $fileID   = '';
my $token    = '';
my $token_timeout = '';
my $log_folder    = $cfg->param('log_dir');
my $upload_folder = $cfg->param('file_upload_dir');
my $deb_mod       = $cfg->param('debug');

#Check if call from POST or GET method
if ($q->param('POSTDATA')) {
	my @var = $json->decode($$cgi{'POSTDATA'});
	$fileID = $var[0]{'fileID'};
	$token = $var[0]{'token'};
	$token_timeout = $var[0]{'token_timeout'};
}
else{
	$fileID = $q->param('fileID');
	$token = $q->param('token');
	$token_timeout = $q->param('token_timeout');
}

my %perl_response = ();

my $callback = q{};
my $response_text_1 = '';

if ($fileID eq '') {
	print "Content-type: text/htmlnn";
	print "You must specify a file to download.";
	$perl_response{error} = "You must specify a file to download.";
} else {

	my $ua = LWP::UserAgent->new;

		my $response_1 = $ua->get($cfg->param('webso_services').
			uri_encode('/db/get.pl?'.
				$cfg->param('db_type').'='.$cfg->param('t_user').
				'&'.$cfg->param('db_token').'='.$token.
				'&'.$cfg->param('db_token_timeout').'='.$token_timeout));

		if ($response_1->is_success) {
			$response_text_1 = $json->decode($response_1->decoded_content);
			if($response_text_1->{success}->{response}->{numFound} eq 1){
				#check if the user is in the share list or if it is his own file
				my $response_2 = $ua->get($cfg->param('webso_services').
					uri_encode('/db/query.pl?'.
						'qt=browse&fq='.
						$cfg->param('db_type').':'.$cfg->param('t_file').
						' AND '.$cfg->param('id').':'.$fileID.
						' AND ('.$cfg->param('db_share').':'.$response_text_1->{success}->{response}->{docs}[0]->{id}.
						' OR '.$cfg->param('db_user').':'.$response_text_1->{success}->{response}->{docs}[0]->{id}.')&'.
						'wt=json&'.
						'hl=true&'.
						'indent=true'
					));
				if ($response_2->is_success) {
					my $response_text_2 = $json->decode($response_2->decoded_content);
					if($response_text_2->{success}->{response}->{numFound} eq 1){
						$filename = $response_text_2->{success}->{response}->{docs}[0]->{filename_s};
						$file     = $response_text_2->{success}->{response}->{docs}[0]->{file_s};
					}
					else{
						$perl_response{error} = "You don't have the rights to download this file.";
					}
				}else{
					$perl_response{error} = "sources server or service2: ".$response_2->code;
					if ($deb_mod) {
						$perl_response{debug_msg} = $response_2->message;
					}
				}
			}else{
				$perl_response{error} = "No account available";
			}
		}else{
			$perl_response{error} = "sources server or service1: ".$response_1->code;
			if ($deb_mod) {
				$perl_response{debug_msg} = $response_1->message;
			}
		}

	my @fileholder;
	# current date
	my $time = localtime;
	#log file downloads if we have reclamations.

	open(DLFILE, "<$upload_folder/$file");# || Error('open', 'file');
	@fileholder = <DLFILE>;
	close (DLFILE) || Error ('close', 'file');

	open (LOG, ">>$log_folder/download.log");# || Error('open', 'file');
	#Severals informations : Time, IP, username, ressource (hash and filename)
	print LOG "[$time] \t $ENV{REMOTE_ADDR} \t $response_text_1->{success}->{response}->{docs}[0]->{user_s} \t $filename -> $file\n";
	close (LOG);
	undef *response_text_1;

	print "Content-Type:application/x-download\n";
	print "Content-Disposition:attachment;filename=$filename\n\n";
	print @fileholder
}

# my $json_response   = $json->pretty->encode(\%perl_response);

# if ($callback) { 
#     print 'Access-Control-Allow-Origin: *';
#     print 'Access-Control-Allow-Methods: GET'; 
#     print "Content-type: application/javascript; charset=utf-8\n\n";
#     $json_response   = $callback.'('.$json_response.');';
# } else { 
#     # Header for access via browser, curl, etc. 
#     print "Content-type: application/json\n\n"; 
# } 

# print $json_response; 