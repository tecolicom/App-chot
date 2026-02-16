package App::chot::Found;
use v5.14;
use warnings;

=head1 DESCRIPTION

Accumulates paths found by each finder during a single C<run()> invocation.
Replaces the former C<$App::chot::_found_paths> package global.

Passed to all finder instances so that later finders (e.g., Python) can
see paths found by earlier ones (e.g., Command) for shebang-based
interpreter discovery.

=cut

sub new {
    my $class = shift;
    bless {
        paths        => [],   # all paths found so far (across finders)
        types        => [],   # finder types that found results, in order
        finder_paths => {},   # per-finder results: { type => [@paths] }
    }, $class;
}

#
# Accessors (return arrayrefs)
#
sub paths { $_[0]{paths} }
sub types { $_[0]{types} }

#
# Record results from a finder.
# Called by the main loop after each successful get_path().
#
sub add {
    my($self, $type, @paths) = @_;
    push @{$self->{paths}}, @paths;
    push @{$self->{types}}, $type;
    $self->{finder_paths}{$type} = [@paths];
}

#
# Retrieve paths found by a specific finder type.
# e.g., $found->paths_for('Perl') returns Perl finder's paths only.
#
sub paths_for {
    my($self, $type) = @_;
    @{$self->{finder_paths}{$type} // []};
}

1;
