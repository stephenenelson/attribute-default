####
#### default_int.t
####
#### $Revision$
####
#### Tests out the internals for the Default() function.
####

use strict;
use warnings;
use diagnostics;
use Test::More tests=>2;
use Attribute::Default qw(exsub);
use attributes;

###################### Tests #####################

sub fooregular { }
sub foomethod :method { }

# Test out _fill_array_sub for simple case
{
  my $fillsub = Attribute::Default::_get_fill([1, 1], \&fooregular);
  is_deeply( [ $fillsub->() ], [1, 1], "Simple case" );
}

# Tests out _fill_array_sub with offset
{
  my $self = bless [3], "snickerdoodle";
  my $fillsub = Attribute::Default::_get_fill([1, 2], \&foomethod);
  is_deeply( [ $fillsub->( $self ) ], [$self, 1, 2], "Offset" );
}

