#!/usr/bin/perl

$oldrange = "3fa02b8..ff4771b";
$newrange = "a7f17aa..";

sub read_range {
	my $bag = {};
	$bag->{'list'} = [];
	$bag->{'bysha1'} = {};
	$bag->{'bysubject'} = {};

	my $h, $commit = '', $state = '';
	open($h, '-|', 'git', 'log', '--topo-order', '--parents', '--abbrev=7', '--abbrev-commit', $_[0]);
	while (<$h>) {
		if (/^commit (.*)/) {
			$commit = {};
			my @list = split(' ', $1);
			my $sha1 = shift(@list);
			$bag->{'bysha1'}->{$sha1} = $commit;
			$commit->{'sha1'} = $sha1;
			$commit->{'parents'} = \@list;
			$commit->{'header'} = '';
			$commit->{'subject'} = '';
			$commit->{'message'} = '';
			push(@{$bag->{'list'}}, $commit);
			$state = 'header';
		}
		elsif ($state eq 'header' && /^$/) {
			$state = 'body';
		}
		elsif ($state eq 'body') {
			if (/^diff /) {
				$commit->{'diff'} = $_;
				$state = 'diff';
			}
			else {
				$commit->{'body'} .= $_;
				if ($commit->{'subject'} eq '') {
					my $subject = $_;
					chomp $subject;
					$commit->{'subject'} = $subject;
					if (defined($bag->{'bysubject'}->{$subject})) {
						print(STDERR "Warning: ignoring second commit with subject '" . $subject . "'\n");
					}
					else {
						$bag->{'bysubject'}->{$subject} = $commit;
					}
				}
			}
		}
		elsif($state eq 'diff') {
			$commit->{'diff'} .= $_;
		}
	}
	close($h);

	find_boundaries($bag);

	return $bag;
}

sub find_boundaries {
	my $bag = $_[0];

	# make a mapping of all listed parents to their children
	my $children = {};
	foreach my $commit (@{$bag->{'list'}}) {
		foreach my $parent (@{$commit->{'parents'}}) {
			if (defined($children->{$parent})) {
				push(@{$children->{$parent}}, $commit);
			}
			else {
				$children->{$parent} = [ $commit ];
			}
		}
	}

	# remove the parents that we know about
	foreach my $commit (@{$bag->{'list'}}) {
		delete $children->{$commit->{'sha1'}};
	}

	$bag->{'boundaries'} = $children;
}

sub figure_out_branch_structure {
	my $bag = $_[0];

}

sub infer_mapping {
	my $a = $_[0], $b = $_[1];

	my $bysubject = $b->{'bysubject'};
	my %map = (), %reverse = ();
	foreach my $commit (@{$a->{'list'}}) {
		my $subject = $commit->{'subject'};
		if (defined($bysubject->{$subject})) {
			# cannot use $commit directly as key: stringifying it
			# would destroy the contained values
			$map{$commit->{'sha1'}} = $bysubject->{$subject};
			$mapped{$bysubject->{$subject}->{'sha1'}} = $commit;
		}
	}

foreach my $sha1 (keys %{$a->{'bysha1'}}) {
	if (!defined($map{$sha1})) {
		print(STDERR "Removed: $sha1 " . $a->{'bysha1'}->{$sha1}->{'subject'} . "\n");
	}
}

foreach my $sha1 (keys %{$b->{'bysha1'}}) {
	if (!defined($reverse{$sha1})) {
		print(STDERR "Added: $sha1 " . $b->{'bysha1'}->{$sha1}->{'subject'} . "\n");
	}
}
}

sub list_subjects {
	my $list = $_[0]->{'list'};
	foreach my $commit (@$list) {
		print "Commit " . $commit->{'sha1'} . ": " . $commit->{'subject'} . ", parents: " . join(':', @{$commit->{'parents'}}) . "\n";
	}
}

my $oldbag = read_range($oldrange);
my $newbag = read_range($newrange);

infer_mapping($oldbag, $newbag);
