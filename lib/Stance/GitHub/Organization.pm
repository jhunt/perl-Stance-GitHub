package Stance::GitHub::Organization;
use strict;
use warnings;

use Stance::GitHub::Repository;

sub new {
	my ($class, $gh, $object) = @_;

	return bless {
		_github => $gh,

		(map { $_ => $object->{$_} } qw[id login description]),
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

sub repos {
	my ($self) = @_;
	$self->{_repos} ||= [
		map { Stance::GitHub::Repository->new($self->{_github}, $_) }
		@{ $self->{_github}->get($self->{urls}{repos}) } ];
	return @{ $self->{_repos} };
}

sub clear {
	my ($self) = @_;
	delete $self->{_details};
	delete $self->{_repos};
	return $self;
}

=head1 NAME

Stance::GitHub::Organization

Part of Stance::GitHub - A Perl Interface to GitHub

=head1 DESCRIPTION

C<Stance::GitHub> provides an object-oriented interface to the GitHub v3 API.
It wraps up specific parts of the GitHub API in a Perl-ish OO interface,
starting with the C<Stance::GitHub> client object itself, which has methods
for finding organizations (C<Stance::GitHub::Organization>), and from there,
code repositories (C<Stance::GitHub::Repository>) and issues / pull requests
(C<Stance::GitHub::Issue>).

This module defines objects that represent single GitHub organizations.

=head1 INSTANCE METHODS

=head2 details

    my $details = $org->details;

Retrieves the full API object for this organization and returns it.

This method is memoized, so calling it multiple times will not result
in repeated calls to the GitHub API endpoints (a good thing, for rate
limiting!).  To forget the current memoized result, call C<clear()>.

=head2 repos

    for my $repo ($org->repos) {
      # ...
    }

Retrieve the list of repositories that belong to this organization.

This method is memoized, so calling it multiple times will not result
in repeated calls to the GitHub API endpoints (a good thing, for rate
limiting!).  To forget the current memoized result, call C<clear()>.

=head2 clear

    $org->clear;

Clears memoized results, returning the organization object itself.
This allows for chaining.

=cut

1;
