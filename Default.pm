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

our $VERSION = $VERSION = do { my @r = (q$Revision$ =~ /\d+/g); sprintf "%d."."%02d" x $#r, @r };


sub default : ATTR(CODE) {
    my ($package, $glob, $referent, $attr, $defaults, $phase) = @_;

    ref $defaults or $defaults = [$defaults];

    my $orig = *$glob{CODE};
    if (ref $defaults eq 'ARRAY') {
	*$glob = sub {
	    my @filled = ();
	    foreach (0 .. $#_) {
		push @filled, ( defined( $_[$_] ) ? $_[$_] : $defaults->[$_] );
	    }
	    if ($#$defaults > $#_) {
		push(@filled, @$defaults[scalar @_ .. $#$defaults]);
	    }
	    
	    @_ = @filled;
	    
	    goto $orig;
	};
    }
    elsif (ref $defaults eq 'HASH') {
	*$glob = sub {
	    my %args = @_;
	    while (my ($key, $value) = each %$defaults) {
	      defined($args{$key}) or $args{$key} = $value;
	    }
	    @_ = %args;
	    goto $orig;
	}
    }
    else {
	confess "Argument to attribute '$attr' must be an arrayref, scalar, or hashref; stopped";
    }

}

1;
__END__

=head1 NAME

Attribute::Default - Perl extension to assign default values to subroutine arguments

=head1 SYNOPSIS

  package MyPackage;
  use base 'Attribute::Default';

  # Makes person's name default to "jimmy"
  sub introduce : default("jimmy") {
     my ($name) = @_;
     print "My name is $name\n";
  }

  # Make age default to 14, sex default to male
  sub vitals : default({age => 14, sex => 'male'}) {
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

This module attempts to fill that gap. If you would like to have a
subroutine that takes three parameters, but the second two should
default to 'Mister Morton' and 'walked', you can declare it like this:

  package WhateverPackage;
  use base 'Attribute::Default';

  sub what_happened : default(undef, 'Mister Morton', 'walked down the street') {
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
C<default()>, like so:

  package YetAnotherPackage;
  use base 'Attribute::Default';

  sub found_pet : default({name => 'Rufus Xavier Sarsaparilla', pet => 'kangaroo'}) {
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
  

=head1 BUGS

An alpha module. Bugs unknown but probably plentiful. Based on The
Damian's Attribute::Handlers, so shares whatever bugs may be found
there. The installation process cannot use the normal mechanism for
auto-installing Attribute::Handlers, so I'm afraid you'll have to
install it yourself if it's not there.

=head1 AUTHOR

Stephen Nelson, E<lt>steven@jubal.comE<gt>

=head1 SEE ALSO

L<Attribute::Handlers>.

=cut


