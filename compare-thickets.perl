#!/usr/bin/perl

$oldrange = "3fa02b8..ff4771b";
$newrange = "a7f17aa..";

sub read_range {
	my $bag = {};
	$bag->{'list'} = [];
	$bag->{'bysubject'} = {};

	my $h, $commit = '', $state = '';
	open($h, '-|', 'git', 'log', '--topo-order', '--parents', '--abbrev=7', '--abbrev-commit', $_[0]);
	while (<$h>) {
		if (/^commit (.*)/) {
			$commit = {};
			my @list = split(' ', $1);
			$commit->{'sha1'} = shift(@list);
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

	return $bag;
}

sub list_subjects {
	my $list = $_[0]->{'list'};
	foreach my $commit (@$list) {
		print "Commit " . $commit->{'sha1'} . ": " . $commit->{'subject'} . ", parents: " . join(':', @{$commit->{'parents'}}) . "\n";
	}
}

my $oldbag = read_range($oldrange);
my $newbag = read_range($newrange);

list_subjects($newbag);
