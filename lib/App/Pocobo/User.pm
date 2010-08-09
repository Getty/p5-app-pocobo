package App::Pocobo::User;

use Moose;

has controller => (
#	isa => 'App::Pocobo::Role::Controller',
	is => 'ro',
	required => 1,
);

sub net {
	my $self = shift;
	$self->from->net;
}

has yourself => (
	isa => 'Bool',
	is => 'ro',
	required => 1,
	default => sub { 0 },
);

has name => (
	isa => 'Str',
	is => 'rw',
	required => 1,
);

has attributes => (
	isa => 'HashRef',
	is => 'rw',
	default => sub {{}},
);

1;