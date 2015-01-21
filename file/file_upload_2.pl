#!/usr/bin/perl -w

use strict;
use CGI;
use CGI::Carp qw ( fatalsToBrowser );
use JSON;
use LWP::UserAgent;
use Config::Simple;
use File::Basename;
use String::Random;
use URI::Encode qw(uri_encode uri_decode);
use FindBin qw($Bin);

# reading the conf file
my $cfg     = new Config::Simple("$Bin/../webso.cfg");
if (Config::Simple->error()) {
	exit 1;
}

my $deb_mod = $cfg->param('debug');

my $callback = q{};
my %perl_response = ();
my $json = JSON->new->allow_nonref;

$CGI::POST_MAX = 1048576 * 10; #Mégabit * nb
my $safe_filename_characters = "a-zA-Z0-9_.-";
my $upload_dir = $cfg->param('file_upload_dir');

my $query = new CGI;
$callback = $query->param('callback');

# my $filename = $query->param("photo");
my $filename = $query->param('myFile');
my $token    = $query->param('token');
my $token_timeout = $query->param('token_timeout');
# my $mimetype = $query->uploadInfo($filename)->{'Content-Type'};

if ( !$filename ){
	# print $query->header ( );
	# print "There was a problem uploading your photo (try a smaller file).";
	$perl_response{error} = 'Problem uploading, maybe the file too big (>5Mo)';
	# print $query->param;
	# exit;
}
else{

	my ( $name, $path, $extension ) = fileparse ( $filename, '..*' );
	$filename = $name . $extension;
	$filename =~ tr/ /_/;
	$filename =~ s/[^$safe_filename_characters]//g;

	if ( $filename =~ /^([$safe_filename_characters]+)$/ ){
		$filename = $1;
	}
	else{
		$perl_response{error} = 'Filename contains invalid characters';
		die "Filename contains invalid characters";
	}

	my $string_gen = String::Random->new;
	#Generate a 25 character hash.
	my $alea = $string_gen->randregex('\w{25}');

	# my $upload_filehandle = $query->upload("photo");
	my $upload_filehandle = $query->upload("myFile");

	open ( UPLOADFILE, ">", "$upload_dir/$alea" ) or die "$!";
	binmode UPLOADFILE;

	while ( <$upload_filehandle> ){
		print UPLOADFILE;
	}

	close UPLOADFILE;
	# $perl_response{success} = 'File uploaded';
	# $perl_response{name} = $filename;
	# $perl_response{hash} = $alea;
	my $ua = LWP::UserAgent->new;

	my $response_1 = $ua->get($cfg->param('webso_services').
		uri_encode('/db/get.pl?'.
			$cfg->param('db_type').'='.$cfg->param('t_user').
			'&'.$cfg->param('db_token').'='.$token.
			'&'.$cfg->param('db_token_timeout').'='.$token_timeout));
	# my $response_1 = $ua->get($cfg->param('webso_services').uri_encode('/db/get.pl?type_s=user&token_s='.$token.'&token_timeout_l='.$token_timeout));

	if ($response_1->is_success) {
		my $response_text_1 = $json->decode($response_1->decoded_content);
		if($response_text_1->{success}->{response}->{numFound} eq 1){
			my $response_2 = $ua->get($cfg->param('webso_services').
				uri_encode('/db/put.pl?'.
					$cfg->param('db_type').'='.$cfg->param('t_file').
					'&'.$cfg->param('db_filename').'='.$filename.
					'&'.$cfg->param('db_file_id').'='.$alea.
					'&'.$cfg->param('db_user').'='.$response_text_1->{success}->{response}->{docs}[0]->{id}));
			# my $response_2 = $ua->get($cfg->param('webso_services').uri_encode('/db/put.pl?type_s=file&filename_s='.$filename.'&file_s='.$alea.'&user_s='.$response_text_1->{success}->{response}->{docs}[0]->{id}));
			if ($response_2->is_success) {
				$perl_response{success} = 'File uploaded';
				$perl_response{name} = $filename;
				$perl_response{hash} = $alea;
				# $perl_response{mimetype} = $mimetype;
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

	$perl_response{db_status} = $query->Vars;
}

my $json_response   = $json->pretty->encode(\%perl_response);

if ($callback) {
	print 'Access-Control-Allow-Origin: *';
	print 'Access-Control-Allow-Methods: GET, PUT'."\n";
	print "Content-type: application/javascript; charset=utf-8\n\n";
	$json_response   = $callback.'('.$json_response.');';
} else {
	# Header for access via browser, curl, etc.
	print 'Access-Control-Allow-Headers: Content-Type';
	print 'Access-Control-Allow-Origin: x-requested-with';
	print 'Access-Control-Allow-Methods: GET, PUT, OPTIONS'."\n";
	print "Content-type: application/json\n\n";
}

print $json_response;
