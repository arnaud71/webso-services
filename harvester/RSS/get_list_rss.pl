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
	my $r_feedly_rss = get_feedly_rss($query);

	my $count = 0;
	my $i = 0;

	my @tab_res;

	my %already_url;

	while ($r_google_rss->{responseData}{entries}[$i]) {
		my $item = $r_google_rss->{responseData}{entries}[$i++];

		if ($already_url{$$item{'url'}}) {
		    next;
		}
		else {
		    $already_url{$$item{'url'}} = 1;
		}

		$$item{'api'}  = 'google';
		$$item{'language'}  = '-';
	    $count++;
		push @tab_res, $item;

	}

    my $i = 0;

    while ($r_feedly_rss->{results}[$i]) {
    	my $item = $r_feedly_rss->{results}[$i++];



    	#dd($item);
    	#change item to be like google title, website -> url, feedId -> link

        $$item{'link'} = $$item{'website'};
        $$item{'url'} = $$item{'feedId'};
        $$item{'url'} =~ s/^feed\///;
        $$item{'api'}  = 'feedly';

        delete $$item{'feedId'};
        delete $$item{'website'};

        if ($already_url{$$item{'url'}}) {
            next;
        }
        else {
            $already_url{$$item{'url'}} = 1;
        }

    	#keep only french and english feed
    	if ($$item{'language'} eq 'en' || $$item{'language'} eq 'fr') {
            push @tab_res, $item;
            $count++;
        }
    }


	$perl_response{'res'} 		= \@tab_res;
	$perl_response{'count'} 	= $count;
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

	#print $api_google."\n";
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


sub get_feedly_rss {
    my $r_json;
    my $query 		= shift @_;
    my $n = 200;


    #http://cloud.feedly.com/v3/search/feeds?q=query&n=100&local=en
    my $api_feedly = 'http://cloud.feedly.com/v3/search/feeds?q='.$query.'&n='.$n;

    my $ua = LWP::UserAgent->new;
	$ua->timeout(30);

	if ($RANDOM_AGENT) {
    	$ua->agent(rand_ua("browsers"));
	}

	if ($USE_PROXY) {
		$ENV{HTTPS_PROXY} = 'proxyem.etat-ge.ch:80';
        $ENV{"HTTPS_PROXY_USERNAME"} = 'zzrodin';
        $ENV{"HTTPS_PROXY_PASSWORD"} = 'as789HGI1';
        $ua->proxy(['http'], 'http://zzrodin:as789HGI1@proxyem.etat-ge.ch:80');
    	#$ENV{"HTTPS_PROXY_USERNAME"} = 'hegtest';
        #$ENV{"HTTPS_PROXY_PASSWORD"} = 'Bingo07';
	}

	my $response = $ua->get($api_feedly);
	if (($response->is_success) || ($response->is_redirect)) {
		$r_json = $json->decode( $response->decoded_content);
	}
	else {
		print STDERR $response->message;
	}
	return $r_json;

}