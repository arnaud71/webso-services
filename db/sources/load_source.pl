#### just to load several sources from a file
use strict;


use LWP::UserAgent;
use Config::Simple;
use URI::Encode qw(uri_encode uri_decode);

use Data::Dump qw(dd);


my $cfg = new Config::Simple('../../webso.cfg');
my $webso_services = $cfg->param('webso_services');



my $db_url                  = $cfg->param('db_url');
my $db_type                 = $cfg->param('db_type');
my $db_user                 = $cfg->param('db_user');
my $db_level_sharing        = $cfg->param('db_level_sharing');
my $db_source_type          = $cfg->param('db_source_type');



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


open(IN,'url_list.txt');

    use URI::Encode;
    my $uri     = URI::Encode->new( { encode_reserved => 0 } );

while(my $url = <IN>) {
    $url =~ s/(\r|\n)//g;
    push_url($url);
}





sub push_url {
    my $url = shift @_;
    my $encoded = $uri->encode($url);
    #print $encoded."\n";
    #exit;
    $source{$db_url} = $url;



    #my $params = '?source_url='.$url_encoded.'&source_type='.$source{source_type_s}.'&source_user='.$source{source_user_s}.'&source_level_sharing='.$source{source_level_sharing_i};

    my $params = '?'.$db_url.'='.$source{$db_url}
             .'&'.$db_type.'='.$source{$db_type}
             .'&'.$db_user.'='.$source{$db_user}
             .'&'.$db_level_sharing.'='.$source{$db_level_sharing}
             .'&'.$db_source_type.'='.$source{$db_source_type}
             ;
print $webso_services.'db/put.pl'.$params."\n";
    my $response = $ua->get($webso_services.'db/put.pl'.$params);

    if ($response->is_success) {
        print $response->decoded_content;  # or whatever

    }
    else {
        print $webso_services.'db/put.pl'.$params."\n";
        die $response->status_line;
    }
}

