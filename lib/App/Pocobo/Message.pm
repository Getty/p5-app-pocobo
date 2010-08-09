package App::Pocobo::Message;

use Moose;

has text => (
	isa => 'Str',
	is => 'ro',
	required => 1,
);

has attributes => (
	isa => 'HashRef',
	is => 'rw',
	default => sub {{}},
);

has from => (
	isa => 'App::Pocobo::User',
	is => 'ro',
	required => 1,
);

has to => (
	isa => 'ArrayRef[App::Pocobo::User]',
	is => 'ro',
	required => 1,
);

1;