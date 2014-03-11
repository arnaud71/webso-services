#### just to load several sources from a file
use strict;


use LWP::UserAgent;
use Config::Simple;
use URI::Encode qw(uri_encode uri_decode);
use lib '../../harvester/RSS/';
use RssInterface;
use JSON;
use Digest::MD5 qw(md5 md5_hex md5_base64);
use Data::Dump qw(dd);


my $cfg = new Config::Simple('../../webso.cfg');
my $webso_services = $cfg->param('webso_services');


my $db_url                  = $cfg->param('db_url');
my $db_type                 = $cfg->param('db_type');
my $db_user                 = $cfg->param('db_user');
my $db_level_sharing        = $cfg->param('db_level_sharing');
my $db_source_type          = $cfg->param('db_source_type');
my $db_title                = $cfg->param('db_title');
my $db_lang                 = $cfg->param('db_lang');


my %source = (
    $db_type             => 'source',
    $db_user             => 'user_0',
    $db_level_sharing    => 1,
    $db_source_type      => 'rss'
);




# init user_agent
my $ua = LWP::UserAgent->new;
$ua->timeout(10);
$ua->env_proxy;


open(IN,$ARGV[0]);

    use URI::Encode;
    my $uri     = URI::Encode->new( { encode_reserved => 0 } );

while(my $url = <IN>) {
    $url =~ s/(\r|\n)//g;
    push_url($url);
}





sub push_url {
    my $url = shift @_;
    my $json            = JSON->new->allow_nonref;

    my $rss_res = RssInterface::check_rss($url);
    print STDERR "$url has been checked, count is ".$$rss_res{count}. "\n";
    if ($$rss_res{count}>0) {
        my $encoded = $uri->encode($url);

        #print $encoded."\n";
        #exit;
        $source{$db_url} = $url;


        my $json_h = {
            $db_url             =>  $source{$db_url},
            $db_type            =>  $source{$db_type},
            $db_user            =>  $source{$db_user},
            $db_level_sharing   =>  $source{$db_level_sharing},
            $db_source_type     =>  $source{$db_source_type},
            $db_title           =>  $$rss_res{title},
            $db_lang            =>  $$rss_res{lang},
            id                  =>  's_'.md5_hex($source{$db_user}.$source{$db_url})
        };

        push_source($json->encode($json_h));

    }
    else {
        print $url." rss not recognized, not added. code:".$$rss_res{code}."\n";
    }
}

sub push_source {

    my $json_text = shift @_;

    #print $json_text;

    my $req = HTTP::Request->new(
        POST => $cfg->param('ws_db').'update'
    );

    $req->content_type('application/json');
    $req->content('['.$json_text.']');

    my $response = $ua->request($req);


    if ($response->is_success) {
        print $response->decoded_content;        #$perl_response{success} = $json->decode( $response->decoded_content);  # or whatever
    }
    else {
        print 'push of '.dd($req)." ".$response->code."\n";
        #$perl_response{'error'} = 'sources server or service: '.$response->code;

    }


}
