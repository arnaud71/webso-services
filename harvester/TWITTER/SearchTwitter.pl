use strict;
use utf8;
use Data::Dump qw(dd); 
use AnyEvent;
use AnyEvent::Twitter::Stream;
use File::Path qw(make_path remove_tree mkpath);
use JSON;
use Config::Simple;
use Log::Log4perl qw(:easy);


my $lang        = q{};
my $rt          = q{};

my $data_dir    = q{};
my $log_dir     = q{};
my $name        = q{};
my $logconf     = q{};

if (-f $ARGV[0]) {

    my $cfg     = new Config::Simple($ARGV[0]);

    $data_dir        = $cfg->param('data_dir');
    $log_dir         = $cfg->param('log_dir');
    $name            = $cfg->param('name');



    my $logconf = "
        log4perl.logger.error                         = TRACE, errorAppender
        log4perl.appender.errorAppender               = Log::Log4perl::Appender::File
        log4perl.appender.errorAppender.filename      = ".$log_dir."/stream_".$name.".log
        log4perl.appender.errorAppender.layout       = PatternLayout
        log4perl.appender.errorAppender.layout.ConversionPattern=%d - %m{chomp}%n
    ";

    Log::Log4perl::init(\$logconf);

    my $consumer_key    = $cfg->param('consumer_key');
    my $consumer_secret = $cfg->param('consumer_secret');
    my $token           = $cfg->param('token');
    my $token_secret    = $cfg->param('token_secret');

    $lang            = $cfg->param('lang');
    $rt              = $cfg->param('rt');

    my $done = AnyEvent->condvar;

    # to use OAuth authentication

    my $track       = $cfg->param('track');
    my $locations   = $cfg->param('locations');
    my $follow      = $cfg->param('follow');


    my $listener = AnyEvent::Twitter::Stream->new(
        consumer_key    => $consumer_key,
        consumer_secret => $consumer_secret,
        token           => $token,
        token_secret    => $token_secret,
        #locations       => "46.393989, 6.204928,46.178146, 6.204928",

        #46.169706, 6.087512      46.257607, 6.309298
        #locations       => "6.087512,46.169706,6.309298,46.257607",
        #locations       => "-122.75,36.8,-121.75,37.8",
        method          => "filter",

        follow          => $follow,
        track           => $track,
        locations       => $locations,

        on_tweet        => \&process_tweet,

        on_keepalive    => sub {
                            warn "ping\n";
                            },

        on_error        => sub {
                            get_logger("error")->trace("ERROR");
                            },

        on_delete       => sub {
                            my ($tweet_id, $user_id) = @_; # callback executed when twitter send a delete notification

                             },

        timeout         => 45,
    );

    $done->recv;
}

else {
    print STDERR "config file must be provided\n";
}


sub process_tweet{
    my $tweet = shift;
    my @now = localtime();

    my $timeStamp = sprintf("%04d/%02d/%02d",
                            $now[5]+1900, $now[4]+1, $now[3],
                            $now[2],      $now[1],   $now[0]);


    my $json_output = to_json($tweet, {utf8 => 1, indent => 1});
    #print $json_output."\n";

    # filtering option
    my $ok = 1;
    if (!($lang && ($tweet->{lang} eq $lang))) {
        $ok = 0;
    }
    my $filename = $tweet->{id}.'.json';
            if ($tweet->{text} =~ /^RT/) {
                $filename .= '_RT';
                if ($rt ne 'true') {
                    $ok = 0;
                }
            }


    if ($ok) {
        #print "$filename\n";
        print $tweet->{text}."\n";
        mkpath("$data_dir/$name/$timeStamp/");
        get_logger("error")->trace("TRACE:$data_dir/$name/$timeStamp/$filename");
        open(OUT,">$data_dir/$name/$timeStamp/$filename") or die "$data_dir/$name/$timeStamp/$filename";
        print OUT $json_output;
        close OUT;
    }
    #print $timeStamp."\n";

    #mkpath($timeStamp);

    #dd($tweet);
    #warn "$tweet->{user}{screen_name}: $tweet->{text}\n";

}
