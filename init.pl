#!/usr/bin/perl
#######################################
# init.pl
#
# to run after webso install for init db
# and init chmod of files and directories
###########################################

use strict;
use Config::Simple;
use LWP::UserAgent;
use Data::Dump qw(dd);


my $cfg     = new Config::Simple('webso.cfg');

# string for creating admin account 'administrateur: webso2014'
my $init_admin = ' <add><doc>
                      <field name="password_s">402c4609fa66b6ae99b1753598e7ac3f</field>
                      <field name="role_s">administrateur</field>
                      <field name="user_s">administrateur</field>
                      <field name="id">u_70d8ad79866bc6dd1b56408fac126933</field>
                      <field name="jeton_s">false</field>
                      <field name="type_s">user</field>
                      <field name="creation_dt">2014-09-05T14:15:35Z</field>
                      <field name="updating_dt">2014-09-05T14:15:35Z</field>

                   </doc></add>';


my $cfg             = new Config::Simple('webso.cfg');
my $ws_db           = $cfg->param('ws_db');
my $i               = 1;



print "*******************************\n";
print "step :".$i++."\n";
print "create administrateur account\n";
print "*******************************\n\n";
# init user_agent
my $ua = LWP::UserAgent->new;
$ua->timeout(1000);



my $req = HTTP::Request->new(
        POST => $ws_db .'collection1/update?wt=xml'
    );

$req->content_type('text/xml');
$req->content($init_admin);


my $response = $ua->request($req);
if ($response->is_success) {
    print "OK\n";
}
else {
    print "Admin account NOT created\n";
}


print "*******************************\n";
print "step :".$i++."\n";
print "chmod +x for pl\n";
print "*******************************\n\n";

print `chmod -R a+x *.pl`;

print "*******************************\n";
print "step :".$i++."\n";
print "check tmp dir\n";
print "*******************************\n\n";

my $tmp_dir = $cfg->param('cache_fetcher_dir');

if (!-e $tmp_dir) {
    print "$tmp_dir doesn\'t exist\n";
    print "we are trying to create it\n";
    `mkdir $tmp_dir`;
    if (-e $tmp_dir) {
        print "$tmp_dir created with success\n";
        `chmod a+rw $tmp_dir`;
    }
    else {
        print "creation of $tmp_dir impossible\n";
        print "init file stopped, try to correct the previous error before using Webso\n";
        exit;
    }
}
else {
    print "$tmp_dir already available\n";
    `chmod a+rw $tmp_dir`;
}


print "*******************************\n";
print "step :".$i++."\n";
print "check log dir\n";
print "*******************************\n\n";

my $log_dir = $cfg->param('log_dir');

if (!-e $log_dir) {
    print "$log_dir doesn\'t exist\n";
    print "we are trying to create it\n";
    `mkdir $log_dir`;
    if (-e $log_dir) {
        print "$log_dir created with success\n";
        `chmod a+rw $log_dir`;
    }
    else {
        print "creation of $log_dir impossible\n";
        print "init file stopped, try to correct the previous error before using Webso\n";
        exit;
    }
}
else {
    print "$log_dir already available\n";
    `chmod a+rw $log_dir`;
}


print "init is finish, don't forget to start solr and set proxy if necessary";


