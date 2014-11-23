# test the tika service for content extraction
use strict;
use Test::More tests => 1;
#use lib '..';
use Tools;



my $text_1 = '<html><head><title>titre chien et chat</title></head><body>le chien mange le chat</body></html>';


my $text    = Tools::extract_tika_content(\$text_1);
#print $text;
ok($text, "text muste be:'titre chien et chat'".'titre chien et chat');
#tika with other format should be added
