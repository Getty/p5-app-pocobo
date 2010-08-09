package App::Pocobo::Controller::IRC;

use 5.010;
use MooseX::POE;
use POE qw(
	Component::IRC
);

use App::Pocobo::Event::Message;
use App::Pocobo::Message;
use App::Pocobo::User;

with qw(
	MooseX::LogDispatch
	App::Pocobo::Role::Controller
);

has nick => (
	isa => 'Str',
	is => 'ro',
	required => 1,
);

has ircname => (
	isa => 'Str',
	is => 'ro',
	required => 1,
	default => sub { 'pocobo User' },
);

has server => (
	isa => 'Str',
	is => 'ro',
	required => 1,
	default => sub { 'irc.perl.org' },
);

has irc => (
	isa => 'POE::Component::IRC',
	is => 'ro',
	lazy => 1,
	default => sub {
		my $self = shift;
		POE::Component::IRC->spawn( 
			nick => $self->nick,
			ircname => $self->ircname,
			server => $self->server,
		);
	},
);

sub START {
	my ( $self ) = @_;
	$self->logger->debug('START');
	$self->irc->yield( register => 'all' );
    $self->irc->yield( connect => {} );
}

use Data::Dumper;

event irc_001 => sub {
	my ( $self ) = @_;
 	$self->logger->debug('@'.$self->net.' irc 001');
	$self->irc->yield( join => '#pocobo' );
};

event irc_msg => sub {
	my ( $self, $from, $target_users, $text ) = @_[ OBJECT, ARG0 .. $#_ ];
	my @users;
	for (@$target_users) {
		push @users, App::Pocobo::User->new({
			controller => $self,
			name => $_,
			yourself => $self->irc->nick_name eq $_,
		});
	}
	my $event = App::Pocobo::Event::Message->new({
		from => $self,
		message => App::Pocobo::Message->new({
			text => $text,
			from => App::Pocobo::User->new({
				controller => $self,
				name => $from,
				yourself => $self->irc->nick_name eq $from,
			}),
			to => \@users,
		}),
	});
	$self->pocobo->new_event($event);
};

event irc_public => sub {
	my ( $self, @args ) = @_[ OBJECT, ARG0 .. $#_ ];
	$self->irc->yield( join => '#pocobo' );
 	$self->logger->debug(Dumper \@args);
};

event _default => sub {
	my ( $self, @args ) = @_[ OBJECT, ARG0 .. $#_ ];

	my @output;
	
	for my $arg (@args) {
		if ( ref $arg eq 'ARRAY' ) {
			push( @output, '[' . join(', ', @$arg ) . ']' );
		} else {
			push ( @output, "'$arg'" );
		}
	}

	$self->logger->debug('@'.$self->net.' irc default: '.join(' ',@output));
};

1;