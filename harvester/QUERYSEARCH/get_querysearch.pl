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
use HTML::Entities;
use utf8;
use XML::FeedPP;
use Encode qw(decode encode);


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
my $out         = 'json';

my $json    	= JSON->new->allow_nonref;
my %perl_response = (
    );

$perl_response{'error'} = 'none';

if ($q->param('callback')) {
    $callback    = $q->param('callback');
}

if ($q->param('query')) {
    $query    = $q->param('query');
}

if ($q->param('typeQuery')) {
       $type    = $q->param('typeQuery');
   }


if ($q->param('out')) {
       $out    = $q->param('out');
   }

my $new_feed = XML::FeedPP::RSS->new(title => 'webso online search', description =>'webso online search', link => 'http://localhost' );
$new_feed->xmlns('xmlns:media' => 'http://search.yahoo.com/mrss/');

if ($query && $type) {
        $type =~ s/,$//g;

        my @tab_type = split ',',$type;
        my $r_rss;
        my @all_items =();
        foreach my $t (@tab_type) {
            if ($$service{$t}) {

                $r_rss = get_rss($$service{$t}.$query);
                foreach my $i (keys $$r_rss{rss}{channel}{item}) {


                    my $item = $$r_rss{rss}{channel}{item}[$i];
                    $$item{t} = $t;
                    push @all_items,$item;
                }
            }
            else {

                $perl_response{'error'} = 'type does\'nt exist';

            }
        }
     #dd($r_rss);

        my $count = 0;

        foreach my $item (@all_items) {

            if ($$item{t} eq 'google_news') {
                $$item{link}{'$t'} =~ s/http:\/\/news\.google\.com\/news\/url(.*?)&url=(.*?)$/$2/;
                utf8::decode($$item{title}{'$t'});
                utf8::decode($$item{description}{'$t'});
                #print $$item{link}{'$t'} ."\n";

                my $hs = HTML::Restrict->new();
                $$item{description}{'$t'} = $hs->process($$item{description}{'$t'});

            }
            elsif ($$item{t} eq 'reddit') {
                my $hs = HTML::Restrict->new();
                $$item{description}{'$t'} = $hs->process($$item{description}{'$t'});

            }
            elsif ($$item{t} eq 'faroo_news') {
                 my $hs = HTML::Restrict->new();
                 $$item{description}{'$t'} = $hs->process($$item{description}{'$t'});
            }
            elsif ($$item{t} eq 'bing_news') {

                $$item{link}{'$t'} =~ s/http:\/\/www\.bing\.com\/news\/apiclick\.aspx(.*?)&url=(.*?)&(.*?)$/$2/;

                $$item{link}{'$t'} = uri_decode($$item{link}{'$t'});
            }
            elsif ($$item{t} eq 'google_blog') {
              $$item{pubDate}{'$t'} = $$item{'dc$date'}{'$t'};

            }
            elsif ($$item{t} eq 'yahoo_news') {

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

            # clean content

            $$item{description} = clean_content($$item{description});
            $$item{description} = clean_content($$item{description});
            $$item{title}       = clean_content($$item{title});

            $$item{description} = highlight_keywords($$item{description},$query);
            $$item{title}       = highlight_keywords($$item{title},$query);


            #dd($item);exit;

            # delete all other keys
            foreach my $k (keys $item) {
                if ($k !~ /link|description|pubDate|title/) {
                    delete $$item{$k};
                }
            }
            my $new_item = $new_feed->add_item();
            $new_item->title($$item{title});
            $new_item->description($$item{description});
            $new_item->link($$item{link});
            $new_item->pubDate($$item{pubDate});

            #dd($item);
            $count++;
            #$perl_response{'res'} 		= $$r_rss{rss}{channel}{item};

        }
        $perl_response{'res'} 		= \@all_items;
        $perl_response{'count'} 	= $count;
    }

else {
    $perl_response{'error'} = 'no query';
}

my $json_response   = $json->pretty->encode(\%perl_response);


#utf8::encode($json_response);
if ($out eq 'rss') {
    print "Content-type: application/rss+xml\n\n";
    my $rss_str =  $new_feed->to_string(indent=>4);


    #utf8::encode($rss_str);
    print $rss_str;
}
else {
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
}

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

    #print STDERR  $$service{$type}.$query."\n";
	my $response = $ua->get($query);
	if (($response->is_success) || ($response->is_redirect)) {
		my $rss = $response->content;

        #utf8::decode($rss);
        #utf8::decode($rss);
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
	#$r_json =~ s/[\x00-\x08\x0B\x0C\x0E-\x1F]//g;
    return $r_json;

}


sub clean_content {

    my $content = shift @_;

    $content = decode_entities($content);


    return $content;

}


# basic hightlighting of keywords
sub highlight_keywords {

    my ($content,$keywords) = @_;


    my @tab = split / /,$keywords;

    foreach my $k (@tab) {
        if ($content && $k) {

        $content =~ s/$k/<b>$&<\/b>/gis;

        }
    }
    return $content;


}