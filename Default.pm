package Attribute::Default;

####
#### Attribute::Default
####
#### $Id$
####
#### See perldoc for details.
####

use 5.006;
use strict;
use warnings;
no warnings 'redefine';
use attributes;

use base qw(Attribute::Handlers Exporter);

use Carp;
use Symbol;

our $VERSION = do { my @r = (q$Revision$ =~ /\d+/g); sprintf "%d."."%02d" x $#r, @r };

our @EXPORT_OK = qw(exsub);

use constant EXSUB_CLASS => ( __PACKAGE__ . '::ExSub' );

##
## import()
##
## Apparently I found it necessary to export 'exsub'
## by hand. I don't know why. Eventually, it may
## be necessary to turn on some specific functionality
## once 'exsub' is exported for compile-time speed.
##
sub import {
  my $class = shift;
  my ($subname) = @_;
  my $callpkg = (caller())[0];

  if (defined($subname) && $subname eq 'exsub') {
    no strict 'refs';
    *{ "${callpkg}::exsub" } = \&exsub;
  }
  else {
    SUPER->import(@_);
  }
    
}

##
## exsub()
##
## One specifies an expanding subroutine for Default by saying 'exsub
## { YOUR CODE HERE }'. It's run and used as a default at runtime.
##
## Exsubs are marked by being blessed into EXSUB_CLASS.
##
sub exsub(&) {
  my ($sub) = @_;
  ref $sub eq 'CODE' or die "Sub '$sub' can't be blessed: must be CODE ref";
  bless $sub, EXSUB_CLASS;
}

##
## _get_args()
##
## Fairly close to no-op code. Discards the needless
## arguments I get from Attribute::Handlers stuff
## and puts single default arguments into array refs.
##
sub _get_args {
  my ($glob, $orig, $attr, $defaults) = @_[1 .. 4];
  (ref $defaults && ref $defaults ne 'CODE') or $defaults = [$defaults];

  return ($glob, $attr, $defaults, $orig);
}

##
## _is_method()
##
## Returns true if the given reference has a ':method' attribute.
##
sub _is_method {
  my ($orig) = @_;

  foreach ( attributes::get($orig) ) {
    ($_ eq 'method') and return 1;
  }

  return;
}

##
## _extract_exsubs_array()
##
## Arguments:
##    DEFAULTS -- arrayref : The list of default arguments
##
## Returns:
##    hashref: list of exsubs we found and their array indices
##    arrayref: list of defaults without exsubs
##
sub _extract_exsubs_array {
  my ($defaults) = @_;

  my %exsubs = ();
  my @noexsubs = ();

  for ( $[ .. $#$defaults ) {
    if (UNIVERSAL::isa( $defaults->[$_], EXSUB_CLASS )) {
      $exsubs{$_} = $defaults->[$_];
    }
    else {
      $noexsubs[$_] = $defaults->[$_];
    }
  }

  return (\%exsubs, \@noexsubs);
}

##
## _get_arg_func()
##
## Arguments:
##    ORIG: glob reference -- Reference to the function for which we're building a wrapper
##
## Returns:
##    CODEREF -- Reference to a function that, when applied to the subroutine's arguments,
##               returns the $self reference (if a method) as a listref, and the
##               rest of the arguments as a listref.
##
## 
sub _get_arg_func {
  my ($orig) = @_;

  if ( _is_method($orig) ) {
    return sub {
      if (@_ >= 1) {
	my $self = shift;
	return ([$self], [@_]);
      }
      else {
	return ([], []);
      }
    };
  }
  else {
    return sub { return ([], [@_]); };
  }
}



##
## _get_fill()
##
## Returns an appropriate subroutine to process the given defaults.
##
sub _get_fill {
  my ($defaults, $orig) = @_;

  if (ref $defaults eq 'ARRAY') {
    return _fill_array_sub($defaults, _get_arg_func($orig));
  }
  elsif(ref $defaults eq 'HASH') {
    return _fill_hash_sub($defaults, _get_arg_func($orig));
  }
  else {
    return _fill_array_sub([$defaults], _get_arg_func($orig));
  }
}

##
## _fill_array_sub()
##
## Arguments:
##   DEFAULTS: arrayref
##
## Returns the appropriate preprocessor to fill an array
## with defaults.
##
sub _fill_array_sub {
  my ($defaults, $argument_func) = @_;

  my ($exsubs, $noexsubs) = _extract_exsubs_array($defaults);
  if ( %$exsubs ) {
    return sub {
      my ($pre, $args) = $argument_func->(@_);
      my @filled = _fill_arr($noexsubs, @$args);
      my @processed = @filled;
      while (my ($idx, $exsub) = each %$exsubs) {
	defined( $args->[$idx] ) and next;
	$processed[$idx] = &$exsub(@$pre, @filled);
      }
      return ( @$pre, @processed);
    };
  }
  else {
    return sub {
      my ($pre, $args) = $argument_func->(@_);
      return (@$pre, _fill_arr($defaults, @$args));
    };
  }
}

##
## _extract_exsubs_hash()
##
## Arguments:
##
##   DEFAULTS: hashref -- Name-value pairs of defaults
##
## Returns: (array)
##
##   hashref -- name-value pairs of all exsubs
##   hashref -- name-value pairs of all non-exsub defaults
##
## Returns the exsubs in a hash of defaults.
##
sub _extract_exsubs_hash {
  my ($defaults) = @_;

  my %exsubs = ();
  my %noexsubs = ();
  while ( my ($key, $value) = each %$defaults ) {
    if (UNIVERSAL::isa( $value, EXSUB_CLASS ) ) {
      $exsubs{$key} = $value;
    }
    else {
      $noexsubs{$key} = $value;
    }
  }
  return (\%exsubs, \%noexsubs);
}

##
## _fill_hash_sub()
##
## Returns the appropriate preprocessor to fill a hash
## with defaults.
##
sub _fill_hash_sub {
  my ($defaults, $argument_func) = @_;

  my ($exsubs, $noexsubs) = _extract_exsubs_hash($defaults);
  if ( %$exsubs ) {
    return sub {
      my ($pre, $args) = $argument_func->(@_);
      my @filled = _fill_hash($noexsubs, @$args);
      my %processed = @filled;
      while (my ($key, $exsub) = each %$exsubs) {
	(! defined $processed{$key}) or next;
	$processed{$key} = &$exsub(@$pre, @filled);
      }
      return (@$pre, %processed);
    };
  }
  else {
    return sub { 
      my ($pre, $args) = $argument_func->(@_);
      return (@$pre, _fill_hash($defaults, @$args));
    };
  }
}

##
## _get_sub()
##
## Arguments:
##    DEFAULTS: arrayref -- Array of defaults to a subroutine
##    ORIG: code ref -- The subroutine we're applying defaults to
## 
## Returns the appropriate subroutine wrapper that
## will call ORIG with the given default values.
##
sub _get_sub {
  my ($defaults, $orig) = @_;

  my $fill = _get_fill($defaults, $orig);

    return sub {
      @_ = $fill->(@_);
      goto $orig;
    };

}


sub Default : ATTR(CODE) {
  my ($glob, $attr, $defaults, $orig) = _get_args(@_);

  *$glob = _get_sub($defaults, $orig);

}


##
## _fill_hash()
##
## Arguments:
##    DEFAULTS: hashref -- Hash table of default arguments
##    ARGS: list -- The arguments to be filtered
##
## Returns:
##    list -- Arguments with defaults filled in
##
sub _fill_hash {
  my $defaults = shift;
  my %args = @_;
  while (my ($key, $value) = each %$defaults) {
    unless ( defined($args{$key}) ) {
      if ( UNIVERSAL::isa( $value, EXSUB_CLASS ) ) {
	$args{$key} = undef;
      }
      else {
	$args{$key} = $value;
      }
    }
  }
  return %args;
}

##
## _fill_arr()
##
## Arguments:
##    DEFAULTS: arrayref -- Array of default arguments
##    ARGS: list -- The arguments to be filtered
##
## Returns:
##    list -- Arguments with defaults filled in
##
## Implementation note: We go through the list
## a second time to pull out exsubs. This should somehow
## be optimized out, and possibly not happen unless
## exsub has been imported.
##
sub _fill_arr {
  my $defaults = shift;
  my @filled = ();
  foreach (0 .. $#_) {
    push @filled, ( defined( $_[$_] ) ? $_[$_] : $defaults->[$_] );
  }
  if ($#$defaults > $#_) {
    push(@filled, @$defaults[scalar @_ .. $#$defaults]);
  }
  foreach ( @filled ) {
    UNIVERSAL::isa($_, EXSUB_CLASS) and $_ = undef;
  }
  
  return @filled;
}  

##
## _make_exsub_filter()
##
## Pulls all ExSubs out of the two-level defaults list
## and creates a sub that will process them automatically.
##
sub _make_exsub_filter {
  my ($defaults_list) = @_;
  
  my @root_subs = ();
  my @arr_subs = ();
  my @hash_subs = ();
  foreach my $list_idx ($[ .. $#$defaults_list) {
    ref $defaults_list->[$list_idx] or next;
    my $def = $defaults_list->[$list_idx];

    if (UNIVERSAL::isa($def, EXSUB_CLASS)) {
      push(@root_subs, [$def, $list_idx]);
      $defaults_list->[$list_idx] = undef;
    }
    elsif (ref $def eq 'ARRAY') {
      foreach my $ref_idx ($[ .. $#$def) {
	ref $def->[$ref_idx] or next;
	my $defdef = $def->[$ref_idx];
	UNIVERSAL::isa($defdef, EXSUB_CLASS) or next;
	push( @arr_subs, [$defdef, $list_idx, $ref_idx]);
	$def->[$ref_idx] = undef;
      }
    }
    elsif (ref $def eq 'HASH') {
      while (my ($key, $val) = each %$def) {
	UNIVERSAL::isa($val, EXSUB_CLASS) or next;
	push( @hash_subs, [$val, $list_idx, $key] );
	$def->{$key} = undef;
      }
    }
  }

  return sub {
    my ($args, @subargs) = @_;
    foreach (@root_subs) {
      $args->[$_->[1]] = $_->[0](@subargs);
    }
    foreach (@arr_subs) {
      $args->[$_->[1]][$_->[2]] = $_->[0](@subargs);
    }
    foreach (@hash_subs) {
      $args->[$_->[1]]{$_->[2]} = $_->[0](@subargs);
    }
    return @$args;
  };
}

###
### Code comprehension notes: exsubs
###
### It seems I've scrambled my exsub handling. Defaults()
### handles exsubs by sorting them out at compile time
### and storing them elsewhere, then undeffing them in the original
### list of defaults. Default() used to do this
### as well, but I (in my foolishness) forgot what I was doing and
### broke that behavior.
###
### I intend to fix this problem.
###
### It seems the overall process is (or should be) as follows:
###
### Compile time:
### 1. Separate exsubs from rest of defaults
### 2. Choose appropriate subroutine to filter defaults 
###    (aka is-it-a-method? Do I need exsub expansion?)
### 3. Substitute wrapper subroutine for original subroutine
###
### Runtime:
### 1. Interpolate defaults.
### 2. Run exsubs and interpolate results.
###
### I may get some additional clarity by treating exsubs completely separately.
### Right now they're part of the main filter method... but why not have
### multiple filter methods?
###
### Finally, and unrelated, I've figured out how handle :method subs. Easy. Bloody easy.
### At compile time, if I've got a :method marker, add an 'undef' to the beginning of the
### default list. Hmm... no, won't work for hashes... 
###


sub Defaults : ATTR(CODE) {
  my ($glob, $orig, $attr, $defaults_list) = @_[1 .. 4];

  ref $defaults_list eq 'ARRAY' or $defaults_list = [$defaults_list];

  my $exsub_filter = _make_exsub_filter($defaults_list);
  
  my $process_defaults = sub {
    my @args = @_;
    
  ARG: 
    foreach ($[ .. $#args ) {
      if (! defined $args[$_]) {
	$args[$_] = $defaults_list->[$_];
      }
      elsif (ref $args[$_]) {
	if (ref $args[$_] eq 'HASH') {
	  ref $defaults_list->[$_] eq 'HASH' or next ARG;
	  $args[$_] = { _fill_hash( $defaults_list->[$_], %{$args[$_]} ) };
	}
	elsif (ref $args[$_] eq 'ARRAY') {
	  ref $defaults_list->[$_] eq 'ARRAY' or next ARG;
	  $args[$_] = [ _fill_arr($defaults_list->[$_], @{ $args[$_]}) ];
	}
	# Otherwise, it's a kind of ref we don't handle... do nothing
	else { }
      }
    }
    if ($#$defaults_list > $#_) {
      push(@args, @$defaults_list[scalar @_ .. $#$defaults_list]);
    }
    return $exsub_filter->(\@args, @args);
  };
  
  if ( _is_method($orig) ) {
    *$glob = sub {
      @_ = ($_[0], $process_defaults->(@_[ ($[ + 1 ) .. $#_ ]));
      goto $orig;
    };
  }
  else {
    *$glob = sub {
      @_ = $process_defaults->(@_);
      goto $orig;
    };
  }

     
}


1;
__END__

=head1 NAME

Attribute::Default - Perl extension to assign default values to subroutine arguments

=head1 SYNOPSIS

  package MyPackage;
  use base 'Attribute::Default';

  # Makes person's name default to "Jimmy"
  sub introduce : Default("Jimmy") {
     my ($name) = @_;
     print "My name is $name\n";
  }
  # prints "My name is Jimmy"
  introduce();

  # Make age default to 14, sex default to male
  sub vitals : Default({age => 14, sex => 'male'}) {
     my %vitals = @_;
     print "I'm $vitals{'sex'}, $vitals{'age'} years old, and am from $vitals{'location'}\n";
  }
  # Prints "I'm male, 14 years old, and am from Schenectady"
  vitals(location => 'Schenectady');


=head1 DESCRIPTION

You've probably seen it a thousand times: a subroutine begins with a
complex series of C<defined($blah) or $blah = 'fribble'> statements
designed to provide reasonable default values for optional
parameters. They work fine, but every once in a while one wishes that
perl 5 had a simple mechanism to provide default values to
subroutines.

This module attempts to provide that mechanism.

=head2 SIMPLE DEFAULTS

If you would like to have a subroutine that takes three parameters,
but the second two should default to 'Mister Morton' and 'walked', you
can declare it like this:

  package WhateverPackage;
  use base 'Attribute::Default';

  sub what_happened : Default(undef, 'Mister Morton', 'walked down the street') {
    my ($time, $subject, $verb) = @_;

    print "At $time, $subject $verb\n";
  }

and C<$subject> and C<$verb> will automatically be filled in when
someone calls the C<what_happened()> subroutine with only a single
argument.

  # prints "At 12AM, Mister Morton walked down the street"
  what_happened('12AM');

  # prints "At 3AM, Interplanet Janet walked down the street"
  what_happened('3AM', 'Interplanet Janet');

  # prints "At 6PM, a bill got passed into law"
  what_happened('6PM', 'a bill', 'got passed into law');

  # prints "At 7:03 PM, Mister Morton grew flowers for Perl"
  what_happened("7:03 PM", undef, "grew flowers for Perl");

You can also use the default mechanism to handle the named parameter
style of coding. Just pass a hash reference as the value of
C<Default()>, like so:

  package YetAnotherPackage;
  use base 'Attribute::Default';

  sub found_pet : Default({name => 'Rufus Xavier Sarsaparilla', pet => 'kangaroo'}) {
    my %args = @_;
    my ($first_name) = split(/ /, $args{'name'}, 2);
    print "$first_name found a $args{'pet'} that followed $first_name home\n"; 
    print "And now that $args{'pet'} belongs...\n";
    print "To $args{'name'}.\n\n";
  }

  # Prints "Rufus found a kangaroo that followed Rufus home"...
  found_pet();

  # Prints "Rafaella found a kangaroo that followed Rafaella home"...
  found_pet(name => 'Rafaella Gabriela Sarsaparilla');

  # Or...
  found_pet(name => 'Rafaella Gabriela Sarsaparilla', pet => undef);

  # Prints "Albert found a rhinoceros that followed Albert home"...
  found_pet(name => 'Albert Andreas Armadillo', pet => 'rhinoceros');

=head2 DEFAULTING REFERENCES

If you prefer to pass around your arguments as references, rather than
full lists, Attribute::Default can accomodate you. Simply use
C<Defaults()> instead of C<Default()>, and your reference parameters
will have defaults added wherever necessary. For example:

  package StillAnotherPackage;
  use base 'Attribute::Default';

  sub lally : Defaults({part_of_speech => 'adverbs', place => 'here'}, 3) {
    my ($in, $number) = @_;
    print join(' ', ('lally') x $number), ", get your $in->{part_of_speech} $in->{'place'}...\n";
  }

  # Prints "lally lally lally, get your adverbs here"
  lally();

  # Prints "lally, get your nouns here"
  lally({part_of_speech => 'nouns'}, 1);

If an argument reference's type does not match an expected default
type, then it is passed along without any attempt at defaulting.


=head2 DEFAULTING METHOD ARGUMENTS

If you are performing object-oriented programming, you can use the
C<:method> attribute to mark your function as a method. The
C<Default()> and C<Defaults()> attributes ignore the first argument (in
other words, the 'type' or 'self' argument) for functions marked as
methods. So you can use C<Default()> and C<Defaults()> just as for regular functions, like so:

 package Thing;
 use base 'Noun';

 sub new :method :Default({ word => 'train' }) {
    my $type = shift;
    my %args = @_;

    my $self = [ $args->{'word'} ];
    bless $self, $type;
 }

 sub make_sentence :method :Default('to another state') {
    my $self = shift;
    my ($phrase) = @_;

    return "I took a " . $self->[0] . " $phrase"
 }

 # prints "I took a train to another state"
 my $train = Noun->new();
 print $train->make_sentence();

 # prints "I took a ferry to the Statue of Liberty"
 my $ferry = Noun->new( word => 'ferry' );
 print $ferry->make_sentence('to the Statue of Liberty');

=head2 EXPANDING SUBROUTINES

Sometimes it's not possible to know in advance what the default should
be for a particular argument. Instead, you'd like the default to be
the return value of some bit of Perl code invoked when the subroutine
is called. No problem! You can pass an expanding subroutine to the
C<Default()> attribute using C<exsub>, like so:

 use Attribute::Default 'exsub';
 use base 'Attribute::Default';

 sub log_action : Default( undef, exsub { get_time(); } ) {
    my ($verb, $time) = @_;
    print "$verb! That's what's happening at $time\n";
 }

Here, if $time is undef, it gets filled in with the results of
executing get_time().

=head1 BUGS

Subroutine expansion is not yet fully implemented for the C<Defaults()> attribute.

There's an as-yet unmeasured compile time delay as Attribute::Default does its magic.

=head1 AUTHOR

Stephen Nelson, E<lt>senelson@tdl.comE<gt>

=head1 SPECIAL THANKS TO

Christine Doyle, Randy Ray, Jeff Anderson, and my brother and sister monks at www.perlmonks.org.

=head1 SEE ALSO

L<Attribute::Handlers>, L<Sub::NamedParams>, L<attributes>.

=cut


