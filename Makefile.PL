use ExtUtils::MakeMaker;

WriteMakefile(
    'NAME'		=> 'Attribute::Default',
    'VERSION_FROM'	=> 'Default.pm', # finds $VERSION
    'PREREQ_PM'		=> { 'Attribute::Handlers' => 0 }, # e.g., Module::Name => 1.1
    ($] >= 5.005 ?    ## Add these new keywords supported since 5.005
      (ABSTRACT_FROM => 'Default.pm', # retrieve abstract from module
       AUTHOR     => 'Stephen Nelson <steven@jubal.com>') : ()),
);
