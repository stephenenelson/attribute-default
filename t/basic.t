# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl test.pl'

#########################

use Test;
BEGIN { plan tests => 10, todo => [9, 10, 11]};
use Attribute::Default;
ok(1); # If we made it this far, we're ok.

#########################

{
  package Attribute::Default::Test;

  use base qw(Exporter Attribute::Default);

  our @EXPORT_OK = qw(single double hash_vals single_defs);
    
  sub single : Default('single value') {
    return "Here I am: " . join(',', @_);
  }

  sub double : Default('two', 'values') {
    return "Two values: " . join(',', @_);
  }

  sub hash_vals : Default({ val1 => 'val one', val2 => 'val two'}) {
    my %args = @_;
    return "Val 1 is $args{val1}, val 2 is $args{val2}";
  }

  sub single_defs : Defaults([{ type => 'black', name => 'darjeeling', varietal => 'makaibari' }]) {
    my ($args) = @_;

    return "Type: $args->{'type'}, Name: $args->{'name'}, Varietal: $args->{'varietal'}";
  }

  sub double_defs : Defaults([{ item => 'polonious'}, 'fishmonger', [3]]) {
    my ($foo, $bar, $baz) = @_;

    return "$foo->{'item'} $bar @$baz";
  }

}

Attribute::Default::Test->import( qw(single double hash_vals single_defs) );

ok(single(), "Here I am: single value");
ok(single('other value'), "Here I am: other value");
ok(double(), "Two values: two,values");
ok(double('another', 'value'), "Two values: another,value");
ok(double('one is different'), "Two values: one is different,values");
ok(hash_vals(), "Val 1 is val one, val 2 is val two");
ok(hash_vals(val2 => 'totally'), "Val 1 is val one, val 2 is totally");

use constant SINGLE_DEFS_RETURNS => "Type: black, Name: darjeeling, Varietal: makaibariZ";
ok(single_defs(), SINGLE_DEFS_RETURNS);
ok(single_defs({ varietal => 'Risheehat First Flush'}), "Type: black, Name: darjeeling, Varietal: Risheehat First FlushZ");
ok(single_defs("Wrong type of argument"), SINGLE_DEFS_RETURNS);


