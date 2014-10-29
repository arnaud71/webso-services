#!/usr/bin/perl
######################################################################
# sources/check.json
#
# only check that the server is available
#
# inputs: any solr objects
#
# Contributors:
#   - Arnaud Gaudinat : 11/08/2013
######################################################################

use strict;
use CGI;
use JSON;
use lib "..";
use LWP::UserAgent;


my $q       = CGI->new;
my $cgi     = $q->Vars;

# prepare the JSON msg
my $json    = JSON->new->allow_nonref;

my $callback = q{};

my %perl_response = (
    );

if ($q->param('callback')) {
        $callback    = $q->param('callback');
}

$perl_response{'answer'} = 'ok';
my $json_response   = $json->pretty->encode(\%perl_response);

if ($callback) {
    print 'Access-Control-Allow-Origin: *';
    print 'Access-Control-Allow-Methods: GET';
    print "Content-type: application/javascript; charset=utf-8\n\n";
    $json_response   = $callback.'('.$json_response.');';
} else {
    # Header for access via browser, curl, etc.
    print "Content-type: application/json\n\n";
}

print $json_response;
