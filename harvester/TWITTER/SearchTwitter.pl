use strict;
use utf8;
use Data::Dump qw(dd); 
use AnyEvent;
use AnyEvent::Twitter::Stream;

my $consumer_key    = 'ZbIV7yUBmVrZSOEmX5vQ';
my $consumer_secret = 'KZSoAIThrUO2dAPHScuUBAHta6M2sBNzPbokMCoZcs';
my $token           = '539117718-SgGMR9WS9k4xDoOcwwZbTgDzHr67RHZlVYu8pCQF';
my $token_secret    = 'P0A3I1cT3MHyE5Cku8uZZXnzToS6wIZ6xgrhzYioas';




my $done = AnyEvent->condvar;

# to use OAuth authentication
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
    follow           => "15705567,2390651,767,15865878,1068831,79543,858051,930061,1000591,13348,5763262,657863,989,15666380,2182641,10955762",
    #track           => "le",
    #track           => "pantene shampoo,hair shampoo,pantene,aussie shampoo,\"herbal essences\",shampoo,\"head shoulders\",wella,\"vidal sassoon\",\"alberto balsam\",elvive,\"john frieda\",tresemme,\"aussie hair\",\"aussie conditioner\",\"aussie moist\"",
    on_tweet        => sub {
                        my $tweet = shift;
			dd($tweet);                        
                        warn "$tweet->{user}{screen_name}: $tweet->{text}\n";
                        },
    on_keepalive    => sub {
                        warn "ping\n";
                        },
    on_delete       => sub {
                        my ($tweet_id, $user_id) = @_; # callback executed when twitter send a delete notification

                         },
    timeout         => 45,
);


$done->recv;
