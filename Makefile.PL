# Load the Module::Install bundled in ./inc/
use inc::Module::Install;

# Define metadata
name 'App-Pocobo';
all_from 'lib/App/Pocobo.pm';

# Specific dependencies
requires '5.010';
requires 'Moose';
requires 'POE';
requires 'MooseX::POE';
requires 'MooseX::LogDispatch';
requires 'MooseX::Getopt';
requires 'Adam';
requires 'Filter::IRCD';
requires 'POE::Component::IRC';

test_requires 'Test::More';

install_script 'script/pocobo';

auto_set_repository;
auto_manifest;
WriteAll;
