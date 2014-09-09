Webso Service
=============

Webso Service is the last version of webso service.


Perl required module from CPAN
------------------------------

    install XML::FeedPP
    install DateTime::Format::RSS
    install JSON
    install CHI
    install URI::Encode
    install Data::Dump
    install Config::Simple
    install CHI
    install IO::Socket::INET

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

