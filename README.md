Webso Service
=============

Webso Service is the last version of webso service.


Perl required module from CPAN
------------------------------

	install CGI
	install CHI
	install Config::Simple
	install Crypt::SSLeay
	install Crypt::Bcrypt::Easy
	install Data::Dump
	install Data::GUID
	install DateTime::Format::RSS
	install Digest::MD5
	install HTML::Restrict
	install IO::Socket::INET
	install JSON
	install Log::Log4perl
	install LWP::UserAgent
	install RssInterface
	install URI::Encode
	install WWW::UserAgent::Random
	install XML::FeedPP
	install XML::LibXML (dep : libxml2-dev from linux sources)
	install XML::NamespaceSupport
	install XML::SAX
	install XML::XML2JSON

It seems better to use perlbrew with MACOSX (else we notice a http response truncated)

Initialisation
--------------

In the root directory please run:

sudo perl init.pl


Server Installation
-------------------


mv webso-services webso-services_save

git clone https://github.com/arnaud71/webso-services.git

sudo perl init.pl

vi webso.cfg (proxy = 1)


Perl Testing
-------------------
prove t/


naming of test:

02_harvester-fetcher_run.t

test number 02
in directory harvester/ 
file fetcher_run.pl

