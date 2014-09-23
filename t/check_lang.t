use strict;
use lib '..';
use Tools;



my $text_fr = 'le chien mange le chat';
my $text_en = 'the cat it the mouse';
my $text_es = 'Desde el Levante: desde Murcia y Alicante se accede a la población a través de la autovía A-30 hasta Hellín';
my $text_it = ' comuni vengono considerati parte delle province per tutto ciò che concerne l\'amministrazione a livello nazionale';


my $lang    = Tools::extract_tika_lang(\$text_fr);
print "$lang\n";


my $lang    = Tools::extract_tika_lang(\$text_en);
print "$lang\n";

my $lang    = Tools::extract_tika_lang(\$text_es);
print "$lang\n";

my $lang    = Tools::extract_tika_lang(\$text_it);
print "$lang\n";