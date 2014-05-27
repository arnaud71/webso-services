#!/usr/bin/perl
###############################################################
# get_list_rss.pl:
# gives the list rss from a query (use google feed api)
# and compare with what is already in drupal
#
# out:
#	json output file
###############################################################

use strict;
use JSON;
use LWP::UserAgent;
use CGI;
use Data::Dump qw(dd);
use Net::SSL();
use WWW::UserAgent::Random;
use Crypt::SSLeay;
use Config::Simple;

my $cfg = new Config::Simple('../../webso.cfg');

my $USE_PROXY           = $cfg->param('use_proxy');
my $RANDOM_AGENT 		= $cfg->param('random_agent');;
$ENV{PERL_LWP_SSL_VERIFY_HOSTNAME} = 0; # for ssl get (google api)

my $q       = CGI->new;

my $callback	= q{};
my $query		= q{};


my $json    	= JSON->new->allow_nonref;
my %perl_response = (
    );

if ($q->param('callback')) {
    $callback    = $q->param('callback');
}

if ($q->param('query')) {
    $query    = $q->param('query');
}


if ($query) {
	my $r_google_rss = get_google_rss($query);


	# db connection
	#my ($dbh,$err_db) = ResipiConfig::my_connect();

	## check if DB was available
	#if ($err_db) {
    #	print STDERR $err_db."\n";
    #	exit;
	#}


	# query to send to mysql db

	#my $query		= 	"SELECT entity_id,field_url_url FROM resipi.field_data_field_url";


	# do sql query and get results
	#my $sth = $dbh->prepare($query);
	#$sth->execute;

	#if ($dbh->errstr()) {
	#	$perl_response{'error'} = 'drupal db problem';
	#}



	# format sql results to hash perl
	#my $def = q{};


	#my %already;
	#while (my $ref = $sth->fetchrow_hashref()) {
    #	$already{$$ref{field_url_url}} = 1;
	#}

	my $count = 0;
	my $i = 0;

	my @tab_res;
	while ($r_google_rss->{responseData}{entries}[$i]) {
		my $item = $r_google_rss->{responseData}{entries}[$i++];
		#print $$item{url}."\n";
	#	if ($already{$$item{url}}) {
	#		$$item{new} = "0";
	#	}
	#	else {
	#		$$item{new} = "1";
	#		$count++;
	#	}
	    $count++;
		push @tab_res, $item;

	}


	$perl_response{'res'} 		= \@tab_res;
	$perl_response{'count'} 	= $i;
	#$perl_response{'count_new'} = $count;

}
else {
	$perl_response{'error'} = 'no query';
}




my $json_response   = $json->pretty->encode(\%perl_response);
if ($callback) {
    print 'Access-Control-Allow-Origin: *';
    print 'Access-Control-Allow-Methods: GET';
    print "Content-type: application/javascript\n\n";
    $json_response   = $callback.'('.$json_response.');';
} else {
    # Header for access via browser, curl, etc.
    print "Content-type: application/json\n\n";
}

print $json_response;

############################################ end main

sub get_google_rss {
	my $r_json;
	my $query 		= shift @_;
	my $api_google 	= 'https://ajax.googleapis.com/ajax/services/feed/find?v=1.0&q='.$query;

	print $api_google."\n";
	#https://ajax.googleapis.com/ajax/services/feed/find?v=1.0&q=Official%20Google%20Blog&userip=INSERT-USER-IP"
	my $ua = LWP::UserAgent->new;
	$ua->timeout(30);
	if ($RANDOM_AGENT) {
    	$ua->agent(rand_ua("browsers"));
	}

	if ($USE_PROXY) {
		$ENV{HTTPS_PROXY} = 'proxyem.etat-ge.ch:80';
        $ENV{"HTTPS_PROXY_USERNAME"} = 'zzrodin';
        $ENV{"HTTPS_PROXY_PASSWORD"} = 'as789HGI1';
    	#$ENV{"HTTPS_PROXY_USERNAME"} = 'hegtest';
        #$ENV{"HTTPS_PROXY_PASSWORD"} = 'Bingo07';
	}

	my $response = $ua->get($api_google);
	if (($response->is_success) || ($response->is_redirect)) {
		$r_json = $json->decode( $response->decoded_content);

	}
	else {
		print STDERR $response->message;
	}
	return $r_json;

}
