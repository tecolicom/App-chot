package App::lms::Node;

use v5.14;
use warnings;
use Command::Run;

my $NODE;
my $DEBUG;

sub man_cmd {
    my($app, $name, $path) = @_;
    my($pkg) = $name =~ m{^(@[^/]+/[^/]+|[^/]+)};
    return ('npm', 'docs', $pkg // $name);
}

sub get_path {
    my($app, $name) = @_;
    $DEBUG = $app->debug;
    my $node = _find_node() or do {
        warn "  Node not found\n" if $DEBUG;
        return;
    };
    warn "  Using: $node\n" if $DEBUG;

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
            warn "  Found: $path\n" if $DEBUG;
            return $path;
        }
        return;
    }

    warn "  Found: $entry\n" if $DEBUG;
    return $entry;
}

sub _find_node {
    return $NODE if defined $NODE;
    Command::Run->new->command('which', 'node')->update->data
        and return $NODE = 'node';
    return $NODE = '';
}

1;
