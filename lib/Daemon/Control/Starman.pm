package Daemon::Control::Starman;
use strict;
use warnings;
use base 'Daemon::Control';
use Server::Starter qw(start_server);
use Try::Tiny;

our $VERSION = '0.000001';
$VERSION = eval $VERSION;

#XXX handle stdout/stderr between programs
my @accessors = qw(status_file psgi listen socket starman_pid_file interval starman);
sub new {
  my $class = shift;
  my $args = shift;

  my %extra_args;
  @extra_args{@accessors} = delete @$args{@accessors};
  $extra_args{starman} ||= 'starman';

  $args->{program} = \&_program;

  my $self = $class->SUPER::new($args);

  @$self{@accessors} = @extra_args{@accessors};

  return $self;
}

for my $method ( @accessors ) {
  my $accessor = sub {
    my $self = shift;
    $self->{$method} = shift if @_;
    return $self->{$method};
  };
  no strict 'refs';
  *$method = $accessor;
}

sub do_workers {
  my $self = shift;
  my $workers = shift || return;

  $self->read_pid;

  if ( $self->pid && $self->pid_running ) {
    if ($workers > 0) {
      for (0 .. $workers) {
        kill 'TTIN', $self->pid;
      }
      $self->pretty_print( "Adding $workers workers" );
    }
    elsif ($workers < 0) {
      $workers = 0 - $workers;
      for (0 .. $workers) {
        kill 'TTOU', $self->pid;
      }
      $self->pretty_print( "Removing $workers workers" );
    }
  }
  else {
    $self->pretty_print( "Not Running", "red" );
  }
}

sub do_refresh {
  my ( $self ) = @_;
  $self->read_pid;

  if ( $self->pid && $self->pid_running ) {
    kill 'USR1' => $self->pid;
    sleep $self->kill_timeout;
    $self->pretty_print( "Refreshed" );
  }
  else {
    $self->pretty_print( "Not Running", "red" );
  }
}

sub starman_pid {
  my $self = shift;
  open my $fh, '<', $self->starman_pid_file
    or die "can't read starman pid: $!";
  my $pid = do { local $/; <$fh> };
  close $fh;
  chomp $pid;
  return $pid;
}

sub _program {
  my ($self, @args) = @_;
  $SIG{USR1} = sub {
    try {
      my $pid = $self->starman_pid;
      kill 'HUP' => $pid;
    }
    catch {
      warn $_;
    };
  };
  my %opts = (
    ($self->listen ? (port => $self->listen) : ()),
    ($self->socket ? (path => $self->socket) : ()),
    ($self->interval ? (interval => $self->interval) : ()),
    'signal-on-hup' => 'QUIT',
    'signal-on-term' => 'QUIT',
    'status-file' => $self->status_file,
    #'log-file'  => '',
    exec => [],
  );
  my @exec = (
    'starman',
    ($self->listen ? ('--listen' => $self->listen) : ()),
    ($self->socket ? ('--listen' => $self->socket) : ()),
    ($self->starman_pid ? ('--pid' => $self->starman_pid) : ()),
    @args,
    ($self->psgi || ()),
  );

  start_server(%opts, exec => \@exec);
}

1;

__END__

=head1 NAME

Daemon::Control::Starman - Control Starman running via Server::Starter with Daemon::Control

=head1 SYNOPSIS

  Daemon::Control::Starman->new({
    psgi => '',
    status_file => '',
    program_args => ['--preload-app'],
    pid_file => '',
    stderr_file => '',
    stdout_file => '',
    listen => ':5000',
  })->run;

=head1 DESCRIPTION

=head1 AUTHOR

haarg - Graham Knop (cpan:HAARG) <haarg@haarg.org>

=head2 CONTRIBUTORS

None yet.

=head1 COPYRIGHT

Copyright (c) 2013 the App::BCSSH L</AUTHOR> and L</CONTRIBUTORS>
as listed above.

=head1 LICENSE

This library is free software and may be distributed under the same terms
as perl itself.

=cut
