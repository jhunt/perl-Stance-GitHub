package Stance::GitHub::Repository;
use strict;
use warnings;

use Stance::GitHub::Issue;

sub new {
	my ($class, $gh, $object) = @_;

	return bless {
		_github => $gh,

		(map { $_ => $object->{$_} } grep { !m/^has/ && !m/_url$/ } keys %$object),
		has => {
			(map {
				my $k = $_; $k =~ s/^has_//;
				$k => !!$object->{$_}
			} grep { m/^has_/ } keys %$object)
		},
		urls => {
			main => $object->{url},
			(map {
				my $k = $_; $k =~ s/_url$//;
				$k => $object->{$_}
			} grep { m/_url$/ } keys %$object)
		}
	}, $class;
}

sub details {
	my ($self) = @_;
	$self->{_details} ||= $self->{_github}->get($self->{urls}{main});
	return $self->{_details};
}

sub issues {
	my ($self) = @_;
	$self->{_issues} ||= [
		return map { Stance::GitHub::Issue->new($self->{_github}, $_) }
		@{ $self->{_github}->get($self->{urls}{issues}) } ];
	return @{ $self->{_issues} };
}

sub clear {
	my ($self) = @_;
	delete $self->{_details};
	delete $self->{_issues};
	return $self;
}

=head1 NAME

Stance::GitHub::Repository

Part of Stance::GitHub - A Perl Interface to GitHub

=head1 DESCRIPTION

C<Stance::GitHub> provides an object-oriented interface to the GitHub v3 API.
It wraps up specific parts of the GitHub API in a Perl-ish OO interface,
starting with the C<Stance::GitHub> client object itself, which has methods
for finding organizations (C<Stance::GitHub::Organization>), and from there,
code repositories (C<Stance::GitHub::Repository>) and issues / pull requests
(C<Stance::GitHub::Issue>).

This module defines objects that represent single GitHub repositories.

=head1 INSTANCE METHODS

=head2 details

    my $details = $repo->details;

Retrieves the full API object for this repository and returns it.

This method is memoized, so calling it multiple times will not result
in repeated calls to the GitHub API endpoints (a good thing, for rate
limiting!).  To forget the current memoized result, call C<clear()>.

=head2 issues

    for my $issue ($repo->issue) {
      # ...
    }

Retrieve the list of issues (including pull requests) that belong
to this repository.

This method is memoized, so calling it multiple times will not result
in repeated calls to the GitHub API endpoints (a good thing, for rate
limiting!).  To forget the current memoized result, call C<clear()>.

=head2 clear

    $repo->clear;

Clears memoized results, returning the repository object itself.
This allows for chaining.

=cut

1;
