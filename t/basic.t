# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl test.pl'
# $Revision$

use diagnostics;
use lib '..';

#########################

use Test;
BEGIN { plan tests => 21, todo => [20,21] };
use Attribute::Default;
ok(1); # If we made it this far, we're ok.

#########################

{
  package Attribute::Default::Test;

  use base qw(Exporter Attribute::Default);

  no warnings 'uninitialized';

  our @EXPORT = qw(single double hash_vals method_hash single_defs double_defs);
    
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

  sub banish :method : Default({ falstaff => 'Plump Jack' }) {
    my $self = shift;
    my %args = @_;
    return "Banish $args{falstaff}, and banish all the world.";
  }

  sub new : method {
    my $type = shift;
    my $self = {};
    bless $self, $type;
  }

  sub imitate :method :Defaults({ character => 'Prince Hal', quote => 'And yet herein will I imitate the sun'}) {
    my $self = shift;
    my ($in) = @_;

    return "$in->{character}: $in->{quote}";
  } 

  sub single_defs : Defaults({ type => 'black', name => 'darjeeling', varietal => 'makaibari' }) {
    my ($args) = @_;

    return "Type: $args->{'type'}, Name: $args->{'name'}, Varietal: $args->{'varietal'}";
  }

  sub double_defs : Defaults({ 'item' => 'polonious'}, 'fishmonger', [3]) {
    my ($foo, $bar, $baz) = @_;

    return "$foo->{'item'} $bar @$baz";
  }

}

Attribute::Default::Test->import();

ok(single(), "Here I am: single value");
ok(single('other value'), "Here I am: other value");
ok(double(), "Two values: two,values");
ok(double('another', 'value'), "Two values: another,value");
ok(double('one is different'), "Two values: one is different,values");
ok(hash_vals(), "Val 1 is val one, val 2 is val two");
ok(hash_vals(val2 => 'totally'), "Val 1 is val one, val 2 is totally");
my $test = Attribute::Default::Test->new();
ok($test->banish(), "Banish Plump Jack, and banish all the world.");
ok($test->imitate(), "Prince Hal: And yet herein will I imitate the sun");

ok(single_defs(), "Type: black, Name: darjeeling, Varietal: makaibari");
ok(single_defs({ varietal => 'Risheehat First Flush'}), "Type: black, Name: darjeeling, Varietal: Risheehat First Flush");
ok(single_defs("Wrong type of argument"), 'Type: , Name: , Varietal: ');

ok(double_defs(), 'polonious fishmonger 3');
ok(double_defs({item => 'hamlet'}, 'dane', [undef, 5]), 'hamlet dane 3 5');

{
  package Attribute::Default::TestExpand;
  use Attribute::Default 'exsub';
  use base qw(Attribute::Default);
  use UNIVERSAL;

  sub single_sub : Default(exsub { return "3" } ) {
    return "Should be three: $_[0]";
  }

  sub multi_subs : Defaults( [ 'caius', 'martius', 'coriolanus' ], exsub { [ reverse @{ $_[0] } ] } ) {
    return "@{$_[0]} is backward @{$_[1]}";
  }

  sub threefaces_sub  : Defaults(3, exsub { $_[0] + 1 }, { foo => exsub { $_[0] + 2 } } ) {
    return "$_[0] $_[1] $_[2]{'foo'}";
  }

  sub new { my $self = [3]; bless $self; }

  sub exp_meth :method :Default({foo => exsub { _check_and_mult($_[0], 2); } }) {
    my $self = shift;
    my %args = @_;
    return $args{'foo'};
  }

  sub exp_meths :method :Defaults({bar => exsub { _check_and_mult($_[0], 3); }}) {
    my $self = shift;
    return $_[0]{bar};
  }

  sub _check_and_mult {
    my $self = shift;
    my ($factor) = @_;
    
    unless (UNIVERSAL::isa($self, __PACKAGE__)) {
      warn "Wrong kind of type: got $self";
      return;
    }
    return @$self * $factor;
  }
}
  
ok(Attribute::Default::TestExpand::single_sub(), 'Should be three: 3');
ok(Attribute::Default::TestExpand::multi_subs(), 'caius martius coriolanus is backward coriolanus martius caius');
ok(Attribute::Default::TestExpand::threefaces_sub(), "3 4 5");
ok(Attribute::Default::TestExpand::threefaces_sub(2), "2 3 4");
{
  my $testobj = Attribute::Default::TestExpand->new();
  ok($testobj->exp_meth(), 6);
  ok($testobj->exp_meths(), 9);
}








