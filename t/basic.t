# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl test.pl'

#########################

use Test;
BEGIN { plan tests => 8 };
use Attribute::Default;
ok(1); # If we made it this far, we're ok.

#########################

{
  package Attribute::Default::Test;

  use base qw(Attribute::Default);
    
  sub single : default('single value') {
    return "Here I am: " . join(',', @_);
  }

  sub double : default('two', 'values') {
    return "Two values: " . join(',', @_);
  }

  sub hash_vals : default({ val1 => 'val one', val2 => 'val two'}) {
    my %args = @_;
    return "Val 1 is $args{val1}, val 2 is $args{val2}";
  }

}

ok(&Attribute::Default::Test::single(), "Here I am: single value");
ok(&Attribute::Default::Test::single('other value'), "Here I am: other value");
ok(&Attribute::Default::Test::double(), "Two values: two,values");
ok(&Attribute::Default::Test::double('another', 'value'), "Two values: another,value");
ok(&Attribute::Default::Test::double('one is different'), "Two values: one is different,values");
ok(&Attribute::Default::Test::hash_vals(), "Val 1 is val one, val 2 is val two");
ok(&Attribute::Default::Test::hash_vals(val2 => 'totally'), "Val 1 is val one, val 2 is totally");
