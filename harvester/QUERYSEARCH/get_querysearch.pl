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


use CGI::Carp qw(fatalsToBrowser);
use lib '../..';
use Digest::MD5 qw(md5 md5_hex md5_base64);
use DateTime::Format::RSS;
use Time::localtime;
use Log::Log4perl qw(:easy);
use Config::Simple;
use JSON;
use LWP::UserAgent;
use CGI;
#use Tools;

print("Content Type: text/html\n\n");
my $config_file ='';
#$ENV{SCRIPT_FILENAME} =~ s/(^.*?)(\/webso-services\/)/$1$2/);

print $config_file;



