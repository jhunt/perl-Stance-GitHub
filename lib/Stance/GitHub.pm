package Stance::GitHub;
use strict;
use warnings;

our $VERSION = "1.0.0";

use LWP::UserAgent qw//;
use JSON           qw//;
use HTTP::Request  qw//;

use Stance::GitHub::Organization;

sub from_json {
	JSON->new->utf8->decode(@_);
}
sub to_json {
	JSON->new->utf8->encode(@_);
}

sub new {
	my ($class, $github_addr) = @_;
	$github_addr ||= "https://api.github.com";
	$github_addr =~ s|/$||;

	bless {
		 ua     => LWP::UserAgent->new(agent => __PACKAGE__.'/'.$VERSION),
		 github => $github_addr,
		_debug  => $ENV{STANCE_GITHUB_DEBUG} && $ENV{STANCE_GITHUB_DEBUG} eq 'on',
		_error  => undef,
	}, $class;
}

sub debug {
	my ($self, $on) = @_;
	$self->{_debug} = !!$on;
}

sub url {
	my ($self, $rel) = @_;
	if ($rel && $rel =~ m/^https?:/) {
		$rel =~ s/\{.*?\}//g; # remove any leftover templating
		return $rel; # is absolute, probably from a GH response...
	}

	$rel ||= '/';
	$rel =~ s|^/||;

	return "$self->{github}/$rel";
}

sub get {
	my ($self, $url) = @_;

	my $req = HTTP::Request->new(GET => $self->url($url))
		or die "unable to create GET $url request: $!\n";
	$req->header('Accept' => 'application/json');
	$req->header('Authorization', 'token [REDACTED]')
		if $self->{_token};
	if ($self->{_debug}) {
		print STDERR "=====[ GET $url ]========================\n";
		print STDERR $req->as_string;
		print STDERR "\n\n";
	}
	$req->header('Authorization', 'token '.$self->{_token})
		if $self->{_token};

	my $res = $self->{ua}->request($req)
		or die "unable to send GET $url request: $!\n";
	if ($self->{_debug}) {
		print STDERR "-----------------------------------------\n";
		print STDERR $res->as_string;
		print STDERR "\n\n";
	}

	my $body = from_json($res->decoded_content);
	if (!$res->is_success) {
		$self->{_error} = $body;
		return undef;
	}
	return $body;
}

sub post {
	my ($self, $url, $payload) = @_;

	my $req = HTTP::Request->new(POST => $self->url($url))
		or die "unable to create POST $url request: $!\n";
	$req->header('Accept' => 'application/json');
	$req->header('Content-Type', 'application/json');
	$req->header('Authorization', 'token [REDACTED]')
		if $self->{_token};
	$req->content(to_json($payload)) if $payload;
	if ($self->{_debug}) {
		print STDERR "=====[ POST $url ]========================\n";
		print STDERR $req->as_string;
		print STDERR "\n\n";
	}
	$req->header('Authorization', 'token '.$self->{_token})
		if $self->{_token};

	my $res = $self->{ua}->request($req)
		or die "unable to send POST $url request: $!\n";
	if ($self->{_debug}) {
		print STDERR "-----------------------------------------\n";
		print STDERR $res->as_string;
		print STDERR "\n\n";
	}

	my $body = from_json($res->decoded_content);
	if (!$res->is_success) {
		$self->{_error} = $body;
		return undef;
	}
	return $body;
}

sub last_error {
	my ($self) = @_;
	return $self->{_error};
}

sub authenticate {
	my ($self, $method, $creds) = @_;

	if ($method eq 'token') {
		$self->{_token} = $creds;
		return $self;
	}

	die "unrecognized authentication method '$method'!";
}

sub orgs {
	my ($self) = @_;
	$self->{_orgs} ||= [
		map { Stance::GitHub::Organization->new($self, $_) }
		@{ $self->get('/user/orgs') }
	];
	return @{ $self->{_orgs} };
}

sub clear {
	my ($self) = @_;
	delete $self->{_orgs};
	return $self;
}

=head1 NAME

Stance::GitHub - A Perl Interface to GitHub

=head1 DESCRIPTION

C<Stance::GitHub> provides an object-oriented interface to the GitHub v3 API.
It wraps up specific parts of the GitHub API in a Perl-ish OO interface,
starting with the C<Stance::GitHub> client object itself, which has methods
for finding organizations (C<Stance::GitHub::Organization>), and from there,
code repositories (C<Stance::GitHub::Repository>) and issues / pull requests
(C<Stance::GitHub::Issue>).

=head1 SYNOPSIS

This is an object-oriented library; first create a GitHub object:

    use Stance::GitHub;

    my $github = Stance::GitHub->new();

Then, you'll need to authenticate.  Currently, only I<personal
access tokens> are supported.

    $github->authenticate(token => $ENV{GITHUB_TOKEN});

After that, you can recurse through organizations into
repositories, and finally to issues (which include pull requests):

    for my $org ($github->orgs) {
      for my $repo ($org->repos) {

        print "$org->{login} / $repo->{name}:\n";
        for my $issue ($repo->issues) {
          printf "%- 5s  %-30.30s  %-10.10s  [%s]\n",
            $issue->{number},
            $issue->{title},
            $issue->{user}{login},
            $issue->{updated_at};
        }
        print "\n";
      }
    }

Remember, GitHub limits requests, even authenticated ones!

=head1 CONSTRUCTOR METHODS

=head2 new

Creates a new client object, and returns it.

=head1 INSTANCE METHODS

=head2 authenticate

    $github->authenticate(token => $ACCESS_TOKEN);

Set authentication parameters for subsequent requests to the GitHub API.
Currently, only the C<token> authentication scheme is understood.

Returns the client object itself, to allow (and encourage) chaining off
of the C<new()> constructor:

    my $c = Stance::GitHub->new()->authenticate(token => $T);

=head2 orgs

Retrieves all GitHub organizations visible by the current
credentials.  Returns a list of C<Stance::GitHub::Organization>
objects.

This method is memoized, so calling it multiple times will not result
in repeated calls to the GitHub API endpoints (a good thing, for rate
limiting!).  To forget the current memoized result, call C<clear()>.

=head2 debug

    $github->debug(1);

Enables or disables debugging.  When debugging is enabled, HTTP
requests and responses will be printed to standard error, to aide
in troubleshooting efforts.

=head2 last_error

    die $github->last_error;

Whenever a logical failure (above the transport) occurs, the GitHub
client stores it for later retrieval.  This method retrieves the most
recently encountered error.

Note that intervening successes will not clear the error, so it's best
to only rely on this method when another method has signaled failure
(i.e. by returning C<undef> in place of an actual result.)

=head2 clear

    $github->clear;

Clears memoized results, returning the client object itself.
This allows for chaining.

=cut

1;
