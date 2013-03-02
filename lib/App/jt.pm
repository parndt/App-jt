package App::jt;
use Moo;
use MooX::Options;
use JSON;
use IO::Handle;

has output_handle => (
    is => "ro",
    default => sub {
        my $io = IO::Handle->new;
        $io->fdopen( fileno(STDOUT), "w");
        return $io;
    }
);

option 'ugly' => (
    is => "ro",
    doc => "Produce uglyfied json output"
);

option 'pick' => (
    is => "ro",
    format => "i@",
    autosplit => "..",
    doc => "`--pick n`: Pick n objects randomly. `--pick n..m`: Pick object in this range."
);

option 'csv' => (
    is => "ro",
    default => sub { 0 },
    doc => "Produce csv output for scalar values."
);

option 'tsv' => (
    is => "ro",
    default => sub { 0 },
    doc => "Produce csv output for scalar values."
);

option 'csv' => (
    is => "ro",
    default => sub { 0 },
    doc => "Produce csv output for scalar values."
);

option 'silent' => (
    is => "ro",
    doc => "Silent output."
);

option 'fields' => (
    is => "ro",
    format => "s@",
    autosplit => ","
);

option 'map' => (
    is => "ro",
    format => "s",
    doc => "Run the specified code for each object, with %_ containing the object content."
);

has data => ( is => "rw" );

sub run {
    my ($self) = @_;
    binmode STDIN => ":utf8";
    binmode STDOUT => ":utf8";

    my $text = do { local $/; <STDIN> };
    $self->data(JSON::from_json($text));
    $self->transform;

    if ($self->csv) {
        $self->output_csv;
    }
    if ($self->tsv) {
        $self->output_tsv;
    }
    elsif (!$self->silent) {
        $self->output_json;
    }
}

sub out {
    my ($self, $x) = @_;
    $x .= "\n" unless substr($x, -1, 1) eq "\n";
    $self->output_handle->print($x);
}

sub output_json {
    my ($self) = @_;
    $self->out( JSON::to_json( $self->data, { pretty => !($self->ugly) }) );
}

sub output_asv {
    require Text::CSV;

    my ($self, $args) = @_;
    my $o = $self->data->[0] or return;
    my @keys = grep { !ref($o->{$_}) } keys %$o;

    my $csv = Text::CSV->new({ binary => 1, %$args });
    $csv->combine(@keys);

    $self->out($csv->string);

    for $o (@{ $self->{data} }) {
        $csv->combine(@{$o}{@keys});
        $self->out( $csv->string );
    }
}

sub output_csv {
    my ($self) = @_;
    $self->output_asv({ sep_char => "\t" });
}

sub output_tsv {
    my ($self) = @_;
    $self->output_csv({ sep_char => "\t" });
}

sub transform {
    my ($self) = @_;

    if ($self->pick) {
        my ($m, $n) = @{$self->pick};
        if (defined($m) && defined($n)) {
            @{$self->data} = @{ $self->data }[ $m..$n ];
        }
        elsif (defined($m)) {
            my $len = scalar @{ $self->data };
            my @wanted = map { rand($len) } 1..$m;
            @{$self->data} = @{ $self->data }[ @wanted ];
        }
    }

    if ($self->map) {
        my $code = $self->map;
        for my $o (@{ $self->data }) {
            local %_ = %$o;
            eval "$code";
            %$o = %_;
        }
    }
    elsif ($self->fields) {
        my @fields = @{ $self->fields };
        for my $o (@{ $self->data }) {
            my %o = ();
            @o{@fields} = @{$o}{@fields};
            %$o = %o;
        }
    }

    return $self;
}

1;

__END__

=head1 jt - json transformer

=head1 SYNOPSIS

    # prettyfied
    curl http://example.com/action.json | jt

    # uglified
    cat random.json | jt --ugly > random.min.json

    ## The following commands assemed the input is an array of hashes.

    # take only selected fields
    cat cities.json | jt --field name,country,latlon

    # randomly pick 10 hashes
    cat cities.json | jt --pick 10

    # pick 10 hashes from position 100, and uglified the output
    cat cities.json | jt --pick 100..109 --ugly

    # filtered by code
    cat cities.json | jt --grep '$_{country} eq "us"' | jt --field name,latlon

    # convert to csv. Only scalar values are chosen.
    cat cities.json | jt --csv

    # Run a piece of code on each hash
    cat orders.json | jt --map 'say "$_{name} sub-total: " . $_{count} * $_{price}'

    cat orders.json | jt --reduce '...'

=head2 OUTPUT OPTIONS

The default output format is JSON. If C<--csv> is provided then simple fields
are chosen and then converted to CSV. If C<--tsv> is provided then it becomes
tab-separated values. The C<--field> option can be also provided, but array
or hash values are ignored.
