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

use base 'Attribute::Handlers';

use Carp;

our $VERSION = do { my @r = (q$Revision$ =~ /\d+/g); sprintf "%d."."%02d" x $#r, @r };



sub _get_args {
  my ($glob, $attr, $defaults) = @_[1,3,4];
  (ref $defaults && ref $defaults ne 'CODE') or $defaults = [$defaults];
  my $orig = *$glob{CODE};

  return ($glob, $attr, $defaults, $orig);
}

sub _sub {
  my ($attr, $subs, $defaults) = @_;

  defined $subs->{ref $defaults} or confess "Argument to attribute '$attr' must be of one of the following types: ${\( join ',', keys %$subs)}; stopped";
  
  return $subs->{ref $defaults};
}

sub Default : ATTR(CODE) {
    my ($glob, $attr, $defaults, $orig) = _get_args(@_);

    *$glob = _sub($attr, {
			  ARRAY => sub {
			    @_ = _fill_arr($defaults, @_);
			    goto $orig;
			  },
			  HASH => sub {
			    @_ = _fill_hash($defaults, @_);
			    goto $orig;
			  },
			 }, $defaults);
  }

sub DefaultMethod : ATTR(CODE) {
  my ($glob, $attr, $defaults, $orig) = _get_args(@_);

  
  *$glob = _sub($attr, {
		 ARRAY => sub {
		   @_ = ( $_[0], _fill_arr($defaults, @_[ $[ + 1 .. $#_ ]) );
		   goto $orig;
		 },
		 HASH => sub {
		   @_ = ($_[0], _fill_hash($defaults, @_[ $[ + 1 .. $#_ ]));
		   goto $orig;
		 },
		}, $defaults);
}


sub DefaultSub : ATTR(CODE) {
  my ($glob, $attr, $defaults, $orig) = _get_args(@_);
  
  *$glob = _sub($attr, {
		 'ARRAY' => sub {
		   my @expanded_defaults = map { ref $_ eq 'CODE' ? &$_() : $_ } @$defaults;
      @_ = _fill_arr(\@expanded_defaults, @_);
		   goto $orig;
		 },
		 'HASH' => sub {
		   my %expanded_defaults = %$defaults;
		   while ( my ($key, $val) = each %expanded_defaults ) {
		     ref $val eq 'CODE' and $expanded_defaults{$key} = &$val();
		   }
		   @_ = _fill_hash(\%expanded_defaults, @_);
		   goto $orig;
		 },
		 }, $defaults);
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
    defined($args{$key}) or $args{$key} = $value;
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
sub _fill_arr {
  my $defaults = shift;
  my @filled = ();
  foreach (0 .. $#_) {
    push @filled, ( defined( $_[$_] ) ? $_[$_] : $defaults->[$_] );
  }
  if ($#$defaults > $#_) {
    push(@filled, @$defaults[scalar @_ .. $#$defaults]);
  }
  
  return @filled;
}  

sub Defaults : ATTR(CODE) {
  my ($glob, $attr, $defaults_list) = @_[1,3,4];

  ref $defaults_list eq 'ARRAY' or $defaults_list = [$defaults_list];
  
  my $orig = *$glob{CODE};
  *$glob = sub {
    my @args = @_;
    ARG: foreach ($[ .. $#args ) {
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
    @_ = @args;
    goto $orig;
  };


      
}

1;
__END__

=head1 NAME

Attribute::Default - Perl extension to assign default values to subroutine arguments

=head1 SYNOPSIS

  package MyPackage;
  use base 'Attribute::Default';

  # Makes person's name default to "jimmy"
  sub introduce : Default("jimmy") {
     my ($name) = @_;
     print "My name is $name\n";
  }

  # Make age default to 14, sex default to male
  sub vitals : Default({age => 14, sex => 'male'}) {
     my %vitals = @_;
     print "I'm $vitals{'sex'}, $vitals{'age'} years old, and am from $vitals{'location'}\n";
  }


=head1 DESCRIPTION

You've probably seen it a thousand times: a subroutine begins with a
complex series of C<defined($blah) or $blah = 'fribble'> statements
designed to provide reasonable default values for optional
parameters. They work fine, but every once in a while one wishes that
perl 5 had a simple mechanism to provide default values to
subroutines.

This module attempts to fill that gap. 

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

=head2 DEFAULTING METHOD ARGUMENTS

If you are performing object-oriented programming, you can use the C<DefaultMethod()> attribute. C<DefaultMethod>
ignores the first argument (in other words, the 'type' or 'self' argument), so you can use named parameters with
a constructor or method just like the C<Default()> attribute.

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


=head1 BUGS

An alpha module; may change. Based on (The) Damian Conway's
Attribute::Handlers, so shares whatever bugs may be found there.

=head1 AUTHOR

Stephen Nelson, E<lt>steven@jubal.comE<gt>

=head1 SEE ALSO

L<Attribute::Handlers>, L<Sub::NamedParams>.

=cut


