#!/usr/bin/perl
#######################################
# check_waiting.pl
#
# Crawl to update waiting sources
#
# TODO improve with parallèle query
###########################################

use strict;
use warnings;
use LWP::UserAgent;
use Config::Simple;
use URI::Encode qw(uri_encode uri_decode);
use JSON;
use Data::Dump qw(dd);
use IO::Socket::INET;
use Digest::MD5 qw(md5 md5_hex md5_base64);
use Log::Log4perl qw(:easy);
use Time::localtime;
use lib '..';
use FindBin qw($Bin);
use POSIX ();
use constant {
    MAX_PROCESS   => 10,
};

my ($child, $pid, @childs, @process_list, $child_pid);

my $json    = JSON->new->allow_nonref;
my %perl_response = ();

my $cfg                     = new Config::Simple("$Bin/../webso.cfg");
my $webso_services          = $cfg->param('webso_services');
my $db_type                 = $cfg->param('db_type');
my $deb_mod                 = $cfg->param('debug');


my $logconf = "
    log4perl.logger.crawler                         = TRACE, crawlerAppender
    log4perl.appender.crawlerAppender               = Log::Log4perl::Appender::File
    log4perl.appender.crawlerAppender.filename      = ".$cfg->param('log_dir')."crawl_checker.log
    log4perl.appender.crawlerAppender.layout        = PatternLayout
    log4perl.appender.crawlerAppender.layout.ConversionPattern=%d - %m{chomp}%n
";

Log::Log4perl::init(\$logconf);

# init user_agent
my $ua = LWP::UserAgent->new;
$ua->timeout(1000);
#$ua->env_proxy;

my $start = 0;
my $rows  = 10;
my $params = '?'.$db_type.'=source&waiting_b=true';
my $response = $ua->get($webso_services.'db/get.pl'.$params.'&start='.$start.'&rows='.$rows);
my $response_1 ='';
my $response_2 ='';


if ($response->is_success) {
    my $error_msg = q{};

    my $r_json = $json->decode($response->content);
    my $max = $r_json->{success}{response}{numFound};
    my $k = 0; #Counter for the query loop
    my $time = time;
    # print $response->content;

    while ($k*$rows < $max){
        if($k != 0){
            $start = $k*$rows;
            $response = $ua->get($webso_services.'db/query.pl'.$params.'&start='.$start.'&rows='.$rows);
            $r_json = $json->decode($response->content);
        }
        # check all services
        my $i = 0;
        my $j = 0;
        while ($r_json->{success}{response}{docs}[$i]) {
            # Check if the source is to update according to the refresh rate
            my ($year,$mon,$day,$hour,$min,$sec) = split(/[-T:Z]+/, $r_json->{success}{response}{docs}[$i]{updating_dt});
            my $refresh = 0;
            if($r_json->{success}{response}{docs}[$i]{refresh_s}){
                $refresh = int(substr($r_json->{success}{response}{docs}[$i]{refresh_s}, 0, 2));
            }
            else{
                $refresh = 12;
            }
            my $updatetime = POSIX::mktime(0, 0, $hour, $day, $mon-1, $year-1900)+($refresh*3600);
            # Not time to update jump next
            # print $updatetime.' - '.time."\n";

            if($updatetime > $time) {
                print 'Next crawl in '.int(($updatetime-$time)/3600)."h\n";
                $i++;
                next;
            }

            # $pid = fork();
            # if ($pid) { # Parent code
            #     push(@childs, $pid);
            #     $nb_process++;
            #     if ( $nb_process >= $MAX_PROCESS ) {
            #         # on ne lance pas plus de $MAX_PROCESS traitements simultanés
            #         # donc on attend la terminaison d'un des fils...
            #         $waitedpid = wait;
            #         my $children_not_terminated = 1;
            #         while ($children_not_terminated) {
            #             FOUND : {
            #                 for (my $i=0; $i < @children; $i++) {
            #                     if ( $children[$i] == $waitedpid ) {
            #                         splice(@children, $i,1);
            #                         $children_not_terminated = 0;
            #                         last FOUND;
            #                     }
            #                 }
            #             }
            #             if ($children_not_terminated) {
            #               $waitedpid = wait;
            #             }
            #         }
            #         $nb_process--;
            #     }
            # }
            # else { #child
                # Query for each wait source using saved url (maybe problematic if domain name change)
                # $response_1 = $ua->get($r_json->{success}{response}{docs}[$i]{url_s});
                print $r_json->{success}{response}{docs}[$i]{url_s}."\n";
                $response_1 = $ua->get($webso_services.'harvester/QUERYSEARCH/get_querysearch.pl?query='.$r_json->{success}{response}{docs}[$i]{query_s}.'&typeQuery='.$r_json->{success}{response}{docs}[$i]{ressources_s});
                my $content = '';
                eval{
                    $content = $json->decode($response_1->content);
                } or do {
                    $i++;
                    next;
                };

                if ($response_1->is_success) {
                    # For each document in the waiting source
                    $j=0;
                    while ($content->{res}[$j]){
                        $params = '?type_s=document'.
                                  '&source_id_ss='.$r_json->{success}{response}{docs}[$i]{id}.
                                  '&url_s='.$content->{res}[$j]{link}.
                                  '&title_t='.$content->{res}[$j]{title}.
                                  '&title_fr='.$content->{res}[$j]{title}.
                                  '&title_en='.$content->{res}[$j]{title}.
                                  '&content_t='.$content->{res}[$j]{description}.
                                  '&content_fr='.$content->{res}[$j]{description}.
                                  '&content_en='.$content->{res}[$j]{description}.
                                  #'&date_dt='.$response_1->{success}{response}{docs}[$j]{pubDate}. #buggy with the pubDate format
                                  '&read_b=false'.
                                  '&validated_b=false'.
                                  '&waiting_b=true';
                        $response_2 = $ua->get($webso_services.'db/put.pl'.$params);

                        if ($response_2->is_success) {
                            # $perl_response{success} = $json->decode($response_2->content);

                            # Update time
                            my $response_3 = $ua->get($webso_services.'db/change.pl?id='.$r_json->{success}{response}{docs}[$i]{id});
                            print $response_3->content;
                        }
                        else{
                            $perl_response{'error'} = 'sources server or service: '.$response_2->code;
                            if ($deb_mod) {
                                $perl_response{'debug_msg'} = $response_2->message;
                            }
                        }
                        #Don't forget to increment !
                        $j++;
                    }
                }
                else{
                    $perl_response{'error'} = 'sources server or service: '.$response_1->code;
                    if ($deb_mod) {
                        $perl_response{'debug_msg'} = $response_1->message;
                    }
                }

            #     exit(0);
            # }

            $i++;
            #exit;
        }
        $k++;
    }

    # foreach (@childs) { 
    #     waitpid($_,0); 
    # }

    my $json_response   = $json->pretty->encode(\%perl_response);
    print $json_response; 

}
else {
    die $response->status_line;
}
