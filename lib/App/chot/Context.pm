package App::chot::Context;
use v5.14;
use warnings;

=head1 DESCRIPTION

Shared context object for inter-handler data passing.
Replaces the former C<$App::chot::_found_paths> package global.

Created once per C<run()> invocation and passed to all handler instances.
Accumulates results as each handler finds paths, making them available
to subsequent handlers (e.g., Python uses Command's found paths for
shebang-based interpreter discovery).

=cut

sub new {
    my $class = shift;
    bless {
        found_paths   => [],   # all paths found so far (across handlers)
        found_types   => [],   # handler types that found results, in order
        handler_paths => {},   # per-handler results: { type => [@paths] }
    }, $class;
}

#
# Accessors (return arrayrefs)
#
sub found_paths { $_[0]{found_paths} }
sub found_types { $_[0]{found_types} }

#
# Record results from a handler.
# Called by the main loop after each successful get_path().
#
sub add_result {
    my($self, $type, @paths) = @_;
    push @{$self->{found_paths}}, @paths;
    push @{$self->{found_types}}, $type;
    $self->{handler_paths}{$type} = [@paths];
}

#
# Retrieve paths found by a specific handler type.
# e.g., $ctx->paths_for('Perl') returns Perl handler's paths only.
#
sub paths_for {
    my($self, $type) = @_;
    @{$self->{handler_paths}{$type} // []};
}

1;
