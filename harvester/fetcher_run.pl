#!/usr/bin/perl
#####################################################################
#
#  fetcher run
#  to run a fetch for an url
#
# input :
#   - url_to_fetch
#   - fetch_id (md5 of the url_to_fetch)
#   - fetcher_url (url of the original fetcher)
#   - user_agent (if null random)
#   - synchro (synchro or assynchronous communication)
#
# output :
#
#   if synchro
#       - content
#       - code
#       - error
#
#  @TODO:
#       - add asynchronous mode
#
#
#
#
####################################################################

use LWP::UserAgent;
use Config::Simple;
use URI::Encode qw(uri_encode uri_decode);
use JSON;
use CGI;
use CHI;
use Log::Log4perl qw(:easy);


print "Content-type: application/json; charset=utf-8\n\n";
my $json    = JSON->new->allow_nonref;

my $cfg = new Config::Simple('../webso.cfg');
my $webso_services = $cfg->param('webso_services');


my $logconf = "
    log4perl.logger.crawler                         = TRACE, crawlerAppender
    log4perl.appender.crawlerAppender               = Log::Log4perl::Appender::File
    log4perl.appender.crawlerAppender.filename      = ".$cfg->param('log_dir')."cache.log
    log4perl.appender.crawlerAppender.layout        = PatternLayout
    log4perl.appender.crawlerAppender.layout.ConversionPattern=%d - %m{chomp}%n

";
Log::Log4perl::init(\$logconf);


# init the cache dir
my $cache_fetcher_dir   = $cfg->param('cache_fetcher_dir');
my $cache_duration      = $cfg->param('cache_duration');
my $cache_option        = $cfg->param('cache_option');

my $cache = CHI->new( driver => 'File',
        root_dir    => $cache_fetcher_dir,
        expires_in  => $cache_duration,
    );


########### get params
my $q   = CGI->new;
my $url = q{};

$url = 'http://www.lemonde.fr/a-la-une/article/2014/03/15/sfr-l-ingerence-inopportune-de-l-etat_4383690_3208.html';


if ($q->param('url')) {
    $url        = $q->param('url');
}
if ($q->param('callback')) {
    $callback   = $q->param('callback');
}

# init user_agent
my $ua = LWP::UserAgent->new;
$ua->timeout(10);
$ua->env_proxy;

my $url_encoded = $url;

my $r_json;
my $res_content = $cache->get($url_encoded);

# cache version doesn't exist
if ( (!$cache_option) || (!defined $res_content) ) {
    my $params = '?url='.$url_encoded;
    my $response = $ua->get($webso_services.'fetcher_agent/fetcher_agent.pl'.$params);

    if ($cfg->param('debug')) {
        #print $webso_services.'fetcher_agent/fetcher_agent.pl'.$params."\n";
    }



    if ($response->is_success) {
        $r_json = $json->decode( $response->content);
        if ($cfg->param('debug')) {
            #print $webso_services.'fetcher_agent/fetcher_agent.pl'.$params."\n";
            #print $$r_json{content};
        }
        $$r_json{cached} = 'false';
        $cache->set( $url_encoded, $response->content);

    }
    else {
        $$r_json{error} = 'service fetcher_agent is not accessible';
    }
}
else {
   $r_json = $json->decode( $res_content);
   $$r_json{cached} = 'true';
   get_logger("crawler")->trace("CACHEOK: $url");
}


my $json_response   = $json->pretty->encode($r_json);


if ($callback) {
#    print 'Access-Control-Allow-Origin: *';
#    print 'Access-Control-Allow-Methods: GET';
#    print "Content-type: application/javascript\n\n";
    $json_response   = $callback.'('.$json_response.');';
} else {
    # Header for access via browser, curl, etc.
#    print "Content-type: application/json\n\n";
}

print $json_response;