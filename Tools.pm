package Tools;

use strict;
use LWP::UserAgent;
use Config::Simple;
use URI::Encode qw(uri_encode uri_decode);
use JSON;
use Data::Dump qw(dd);
use IO::Socket::INET;
use Digest::MD5 qw(md5 md5_hex md5_base64);
use Log::Log4perl qw(:easy);
use Time::localtime;



my $json    = JSON->new->allow_nonref;

my $cfg             = new Config::Simple('../webso.cfg');
my $webso_services  = $cfg->param('webso_services');
my $tika_text       = $cfg->param('tika_text');


my $db_url                  = $cfg->param('db_url');
my $db_type                 = $cfg->param('db_type');
my $db_user                 = $cfg->param('db_user');
my $db_level_sharing        = $cfg->param('db_level_sharing');
my $db_source_type          = $cfg->param('db_source_type');


# init user_agent
my $ua = LWP::UserAgent->new;
$ua->timeout(1000);
$ua->env_proxy;


######################################################################
#
# fetch docs from a source and index if (indexing = 'true')
#
# input
#   - url : url of the source
#   - crawl_link : crawl the links contains in the source
#   - indexing : index the fetched content
#
sub fetchDocSource {
    my $error_msg = q{};
    my ($source,$crawl_link,$indexing) = @_;
    #$$doc{url_s} = 'http://feeds.feedburner.com/bitem/news';

    my $url_source = $$source{url_s};
    #print $url_source."\n";

    my $params = '?url='.$url_source;
    if ($crawl_link) {
        $params.= '&crawl_link='.$crawl_link;
    }
    my $res_rss = $ua->get($webso_services.'harvester/RSS/get_rss.pl'.$params);
    #print $webso_services.'harvester/RSS/get_rss.pl'.$params;exit;

    my $r_json_rss;



    if ($res_rss->is_success) {

        $r_json_rss = $json->decode( $res_rss->content);

        #dd($r_json_rss);exit;
        my $num_doc = 0;
        foreach my $h (@{$r_json_rss->{items}} ) {
            print STDERR $$h{link}."\n";
            my $main_content    = extract_tika_content(\$$h{content});
            utf8::encode($main_content);
            $main_content =~ s/$$h{title}//gs;

            my $meta_flag = 'false';
            # if not enough take the content from meta instead of crawling
            if ((length($main_content)<20) && (length($$h{meta_content})>19)) {
                $main_content   = $$h{meta_content};
                $meta_flag      = 'true';
            }

            my $lang    = extract_tika_lang(\$$h{content});
            #print $lang."\n";

            #print dd($h);exit;

            if (($indexing eq 'true') && $main_content) {
                my $tm = localtime;
                my $str_now = sprintf("%04d-%02d-%02d".'T'. "%02d:%02d:%02d".'Z', $tm->year+1900,($tm->mon)+1, $tm->mday, $tm->hour, $tm->min, $tm->sec);


                my $doc = {
                        id              => 'd_'.md5_hex($$source{user_s}.$$h{link}),
                        date_dt         => $$h{date},
                        url_s           => $$h{link},
                        user_s          => $$source{user_s},
                        content_en      => $main_content,
                        content_fr      => $main_content,
                        content_t       => $main_content,
                        raw_s           => $$h{content},
                        type_s          => 'document',
                        title_t         => $$h{title},
                        title_en        => $$h{title},
                        title_fr        => $$h{title},
                        lang_s          => $lang,
                        read_b          => 'false',
                        source_id_ss    => $$source{id},
                        meta_flag_b     => $meta_flag,
                        creation_dt     => $str_now,
                        updating_dt     => $str_now
                };

                if (push_doc($json->encode($doc))) {
                    $num_doc++;
                }

            }
            else {
                        #    get_logger("crawler")->trace("ERROR: tika content extration empty".$$h{link});
            }
        } # end foreach
        $$r_json_rss{nb} = $num_doc;


    }

    else {
        $error_msg = 'service get_rss.pl is not accessible';
    }


    return($r_json_rss);
}



##############################
# extract_tika_content
#
#   input: raw html
#   output: relevant text
##############################
sub extract_tika_content{
    my ($data) = shift @_;

    #print $$data;
    #  We call IO::Socket::INET->new() to create the UDP Socket
    # and bind with the PeerAddr.

    my $socket = new IO::Socket::INET (
        PeerAddr    => '195.176.237.196',
        PeerPort    => '8331',
        Proto       => 'tcp'
    ) or die "ERROR in Socket Creation : $!\n";
    #send operation


    my $size = $socket->send($$data);
    #print "sent data of length $size\n";

    # notify server that request has been sent
    shutdown($socket, 1);

    my $response = "";

    my $content ='';
    while (my $line = <$socket>)
    {
        $content .= $line;
    }

    close($socket);
    utf8::decode($content);
    return $content;
}

##############################
# extract_tika_lang
#
#   input: raw html
#   output: detected language of the content
##############################
sub extract_tika_lang{
    my ($data) = shift @_;

    #print $$data;
    #  We call IO::Socket::INET->new() to create the UDP Socket
    # and bind with the PeerAddr.

    my $socket = new IO::Socket::INET (
        PeerAddr    => '195.176.237.196',
        PeerPort    => '8333',
        Proto       => 'tcp'
    ) or die "ERROR in Socket Creation : $!\n";
    #send operation

    my $size = $socket->send($$data);
    #print "sent data of length $size\n";

    # notify server that request has been sent
    shutdown($socket, 1);

    my $response = "";

    my $lang ='';
    while (my $line = <$socket>)
    {
        $lang .= $line;;
    }

    close($socket);

    $lang =~ s/(\r|\n)//g;
    return $lang;
}


##############################
# push_doc
#
#   input: doc in json
#   output: response code and/or error msg
##############################
sub push_doc {

    my $json_text = shift @_;


    #print $json_text;

    my $req = HTTP::Request->new(
        POST => $cfg->param('ws_db').'update'
    );

    $req->content_type('application/json;charset=utf-8');


    $req->content('['.$json_text.']');

    my $response = $ua->request($req);


    if ($response->is_success) {
        return 1;
        #print $response->content;
        #$perl_response{success} = $json->decode( $response->decoded_content);  # or whatever

    }
    else {
        print STDERR 'doc server or service: '.$response->code;
        return 0;
        #$perl_response{'error'} = 'sources server or service: '.$response->code;

    }


}


sub check_watch {


}


return 1;