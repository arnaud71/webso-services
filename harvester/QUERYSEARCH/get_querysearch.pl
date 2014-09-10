#!/usr/bin/perl
#####################################################################
#
#  query search harvester (on google news, google blog, delicious)
#
#
# input:
#   - query : query to search
#
#
####################################################################

use strict;


use strict;
use JSON;
use LWP::UserAgent;
use CGI;
use Data::Dump qw(dd);
use Net::SSL();
use WWW::UserAgent::Random;
use Crypt::SSLeay;
use Config::Simple;
use XML::XML2JSON;
use HTML::Restrict;
use URI::Encode qw(uri_encode uri_decode);


my $service = {

    reddit     => 'http://www.reddit.com/search.rss?sort=new&q=',

    faroo_news => 'http://www.faroo.com/api?start=1&length=10&l=en&src=news&f=rss&q=',


    google_news => 'https://news.google.com/news?pz=1&ned=us&hl=en&output=rss&q=',
    # title.$t description.$t pubDate.$t link.$t (description in html)
    delicious   => 'http://delicious.com/v2/rss/popular/',
    # title.$t description.$t pubDate.$t link.$t
    yahoo_news  => 'http://news.search.yahoo.com/rss?ei=UTF-8&p=',
    # title.$t description.$t pubDate.$t link.$t
    bing_news   => 'http://www.bing.com/news/search?format=RSS&q=',
    # title.$t description.$t pubDate.$t link.$t
    google_blog => 'https://www.google.com/search?hl=en&tbm=blg&tbs=qdr:d&output=rss&q=',
    # title.$t description.$t pubDate.$t link.$t
    #yahoo_blog  => 'http://blog.search.yahoo.com/rss?ei=UTF-8&p='

};




my $cfg = new Config::Simple('../../webso.cfg');

my $USE_PROXY           = $cfg->param('use_proxy');
my $RANDOM_AGENT 		= $cfg->param('random_agent');;
$ENV{PERL_LWP_SSL_VERIFY_HOSTNAME} = 0; # for ssl get (google api)

my $q       = CGI->new;

my $callback	= q{};
my $query		= q{};
my $type        = q{};

my $json    	= JSON->new->allow_nonref;
my %perl_response = (
    );

if ($q->param('callback')) {
    $callback    = $q->param('callback');
}

if ($q->param('query')) {
    $query    = $q->param('query');
}

if ($q->param('typeQuery')) {
       $type    = $q->param('typeQuery');
   }


if ($query && $type) {
    if ($$service{$type}) {
        my $r_rss = get_rss($$service{$type}.$query,$type);
     #dd($r_rss);

        my $count = 0;
        foreach my $i (keys $$r_rss{rss}{channel}{item}) {
            my $item = $$r_rss{rss}{channel}{item}[$i];

            if ($type eq 'google_news') {
                $$item{link}{'$t'} =~ s/http:\/\/news\.google\.com\/news\/url(.*?)&url=(.*?)$/$2/;
                #print $$item{link}{'$t'} ."\n";

                my $hs = HTML::Restrict->new();
                $$item{description}{'$t'} = $hs->process($$item{description}{'$t'});

            }
            elsif ($type eq 'reddit') {
                my $hs = HTML::Restrict->new();
                $$item{description}{'$t'} = $hs->process($$item{description}{'$t'});

            }
            elsif ($type eq 'faroo_news') {
                 my $hs = HTML::Restrict->new();
                 $$item{description}{'$t'} = $hs->process($$item{description}{'$t'});
            }
            elsif ($type eq 'bing_news') {

                $$item{link}{'$t'} =~ s/http:\/\/www\.bing\.com\/news\/apiclick\.aspx(.*?)&url=(.*?)&(.*?)$/$2/;

                $$item{link}{'$t'} = uri_decode($$item{link}{'$t'});
            }
            elsif ($type eq 'google_blog') {
              $$item{pubDate}{'$t'} = $$item{'dc$date'}{'$t'};

            }
            elsif ($type eq 'yahoo_news') {

                $$item{link}{'$t'} =~ s/http\:\/\/ri\.search\.yahoo\.com\/(.*?)\/RU=(.*?)\/RK(.*?)$/$2/;

                $$item{link}{'$t'} = uri_decode($$item{link}{'$t'});
            }

            # general cleaning ga campaign

            $$item{link}{'$t'} =~ s/\?utm(.*?)$//;

            # remove $t level
            $$item{link}        = $$item{link}{'$t'};
            $$item{description} = $$item{description}{'$t'};
            $$item{pubDate}     = $$item{pubDate}{'$t'};
            $$item{title}       = $$item{title}{'$t'};

            #dd($item);exit;

            # delete all other keys
            foreach my $k (keys $item) {
                if ($k !~ /link|description|pubDate|title/) {
                    delete $$item{$k};
                }
            }
            #dd($item);
            $count++;
            $perl_response{'res'} 		= $$r_rss{rss}{channel}{item};

        }
        $perl_response{'count'} 	= $count;
    }
    else {
        $perl_response{'error'} = 'type does\'nt exist';
    }
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

#####################################
# get_rss
#
# in:
#   query ; url to get

sub get_rss {
    my $r_json;
    my ($query,$type) 		= @_;


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

	my $response = $ua->get($query);
	if (($response->is_success) || ($response->is_redirect)) {
		my $rss = $response->content;


        #if ($type eq 'google_news') {
            #special conversion for google_news

        #    $rss =~ s/&quot;http:\/\/news\.google\.com\/news\/url(.*?)&amp;url=(.*?)&quot;/\n\n&quot;$2&quot;\n\n/g;
            #$rss =~ s/&quot;http:\/\/news\.google\.com\/news\/url//g;

        #}

		my $XML2JSON = XML::XML2JSON->new();
        my $JSON = $XML2JSON->convert($rss);
        $r_json = $json->decode($JSON);


	}
	else {
		print STDERR $response->message;
	}
	return $r_json;

}

