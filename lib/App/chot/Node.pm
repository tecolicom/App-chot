package App::chot::Node;

use v5.14;
use warnings;

use parent 'App::chot::Finder';

use Command::Run;

#
# Use npm docs to open package documentation in browser.
# Extracts package name from scoped or plain module names.
#
sub man_cmd {
    my $self = shift;
    my $name = $self->name;
    my($pkg) = $name =~ m{^(@[^/]+/[^/]+|[^/]+)};
    return ('npm', 'docs', $pkg // $name);
}

#
# Find Node.js module source via require.resolve() with global paths.
# Supports scoped packages (@scope/name) and subpath resolution
# (e.g., "npm/lib/cli" -> package root + subpath).
#
sub get_path {
    my $self = shift;
    my $name = $self->name;
    my $node = $self->_find_node or do {
        warn "  Node not found\n" if $self->debug;
        return;
    };
    warn "  Using: $node\n" if $self->debug;

    # Validate module name (allow scoped packages like @scope/name)
    return if $name =~ /[^\w.\-\/@]/;

    # Split into package name and subpath: "npm/lib/cli" -> ("npm", "lib/cli")
    my($pkg, $subpath) = $name =~ m{^(@[^/]+/[^/]+|[^/]+)(?:/(.+))?$};
    return unless defined $pkg;

    my $code = <<"END";
const paths = require('module').globalPaths;
try { console.log(require.resolve('$pkg', {paths})) } catch(e) {}
END

    my $entry = Command::Run->new->command($node, '-e', $code)->update->data // return;
    chomp $entry;
    return unless $entry && -f $entry;

    if (defined $subpath) {
        # Find package root by locating package.json
        my $dir = $entry;
        while ($dir =~ s{/[^/]+$}{}) {
            last if -f "$dir/package.json";
            return if $dir eq '';
        }
        my $path = "$dir/$subpath";
        $path .= '.js' unless $path =~ /\.\w+$/;
        if (-f $path) {
            warn "  Found: $path\n" if $self->debug;
            return $path;
        }
        return;
    }

    warn "  Found: $entry\n" if $self->debug;
    return $entry;
}

#
# Find available Node.js interpreter. Result is cached per instance.
#
sub _find_node {
    my $self = shift;
    return $self->{_node} if defined $self->{_node};
    Command::Run->new->command('which', 'node')->update->data
        and return $self->{_node} = 'node';
    return $self->{_node} = '';
}

1;
