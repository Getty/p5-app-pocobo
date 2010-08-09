package App::Pocobo::Role::Controller;

use Moose::Role;

has net => (
	isa => 'Str',
	is => 'ro',
	required => 1,
);

with qw(
	App::Pocobo::Role::Pocobo
);

1;