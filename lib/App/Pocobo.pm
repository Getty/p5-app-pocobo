package App::Pocobo;

use 5.010;
use MooseX::POE;

with qw(
	MooseX::Getopt
	MooseX::LogDispatch
);

use App::Pocobo::View::IRC;

has views => (
	isa => 'ArrayRef',
	is => 'rw',
	lazy => 1,
	default => sub {
		my $self = shift;
		[
			App::Pocobo::View::IRC->new({
				net_map => {
					'Perl' => 'p',
					'CubeStatsNet' => 'c',
				},
				logger => $self->logger,
				pocobo => $self,
			}),
		];
	},
);

has events => (
	traits     => ['Array'],
	is         => 'ro',
	isa        => 'ArrayRef',
	default    => sub { [] },
	handles    => {
		all_events		=> 'elements',
		add_event		=> 'push',
		return_event	=> 'unshift',
		next_event		=> 'shift',
		count_events	=> 'count',
	},
);

use App::Pocobo::Controller::IRC;

has controllers => (
	isa => 'ArrayRef',
	is => 'rw',
	lazy => 1,
	default => sub {
		my $self = shift;
		[
			App::Pocobo::Controller::IRC->new({
				net => 'Perl',
				nick => 'pocoboOne',
				server => 'irc.perl.org',
				ircname => 'I\'m a test',
				logger => $self->logger,
				pocobo => $self,
			}),
			App::Pocobo::Controller::IRC->new({
				net => 'CubeStatsNet',
				nick => 'pocoboOne',
				server => 'irc.cubestats.net',
				ircname => 'I\'m a test',
				logger => $self->logger,
				pocobo => $self,
			}),
		];
	},
);

use Data::Dumper;

sub START {
	my ( $self ) = @_;
	$SIG{'__WARN__'} = sub { my $message = $_[0]; chomp $message; $self->logger->debug('sig_warn: '.$message) };
	$self->logger->debug('START');
	$self->views;
	$self->controllers;
}

sub new_event {
	my ( $self, $event ) = @_;
	my $return = 0;
	for (@{$self->views}) {
		$return = 1 if $_->new_event($event);
	}
	$self->add_event($event) unless $return;
}

sub give_events {
	my ( $self, $view ) = @_;
	$self->logger->info($self->count_events);
	while ($self->count_events) {
		my $event = $self->next_event;
		if (!$view->new_event_cached($event)) {
			$self->return_event($event);
			return 0;
		}
	}
	return 1;
}

1;











