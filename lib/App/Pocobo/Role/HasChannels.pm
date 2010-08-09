package App::Pocobo::Role::HasChannels;

use Moose::Role;

has channels => (
	isa => 'ArrayRef[App::Pocobo::Channel]',
	is => 'ro',
	required => 1,
);

1;