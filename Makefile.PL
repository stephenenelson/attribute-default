use ExtUtils::MakeMaker;

# Don't print out warnings caused by Attribute::Handlers already on
# the scene (using same subroutine-augmentation trick as for
# defaults. Funny how many nails there are in this world when you've
# got a shiny hammer...)
{
  no warnings 'redefine';

  my $old_handler = \&ExtUtils::MakeMaker::warnhandler;
  *ExtUtils::MakeMaker::warnhandler = sub {
    $_[0] =~ /^Too late to run/ and return;
    $old_handler->(@_);
  };
}

WriteMakefile(
    'NAME'		=> 'Attribute::Default',
    'VERSION_FROM'	=> 'Default.pm', # finds $VERSION
    'PREREQ_PM'		=> { 'Attribute::Handlers' => 0,
			     'Test::More' => 0
			   }, 
    ($] >= 5.005 ?    ## Add these new keywords supported since 5.005
      (ABSTRACT_FROM => 'Default.pm', # retrieve abstract from module
       AUTHOR     => 'Stephen Nelson <senelson@tdl.com>') : ()),
);
