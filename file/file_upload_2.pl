#!/usr/bin/perl -w

use strict;
use CGI;
use CGI::Carp qw ( fatalsToBrowser );
use JSON;
use File::Basename;
use String::Random;

my $callback = q{};
my %perl_response = ();
my $json = JSON->new->allow_nonref;

$CGI::POST_MAX = 1048576 * 10; #Mégabit * nb
my $safe_filename_characters = "a-zA-Z0-9_.-";
my $upload_dir = "/home/clement/upload";

my $query = new CGI;
$callback = $query->param('callback');

# my $filename = $query->param("photo");
my $filename = $query->param("myFile");

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
	#Generate a 8 character password with 7 alphanumeric and 1 special character at the end.
	my $alea = $string_gen->randregex('\w{25}.');

	# my $upload_filehandle = $query->upload("photo");
	my $upload_filehandle = $query->upload("myFile");

	open ( UPLOADFILE, ">", "$upload_dir/$alea" ) or die "$!";
	binmode UPLOADFILE;

	while ( <$upload_filehandle> ){
		print UPLOADFILE;
	}

	close UPLOADFILE;
	$perl_response{success} = 'File uploaded';
	$perl_response{name} = $filename;
	$perl_response{hash} = $alea;
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
