package App::Pocobo::Role::Pocobo;

use Moose::Role;
use DateTime;

has pocobo => (
	isa => 'App::Pocobo',
	is => 'ro',
	required => 1,
);

1;