package Pod::Weaver::Plugin::ScriptX;

# AUTHORITY
# DATE
# DIST
# VERSION

use 5.010001;
use Moose;
with 'Pod::Weaver::Role::AddTextToSection';
with 'Pod::Weaver::Role::Section';

sub _process_module {
    no strict 'refs';

    my ($self, $document, $input, $package) = @_;

    my $filename = $input->{filename};

    # XXX handle dynamically generated module (if there is such thing in the
    # future)
    local @INC = ("lib", @INC);

    {
        my $package_pm = $package;
        $package_pm =~ s!::!/!g;
        $package_pm .= ".pm";
        require $package_pm;
    }

    my $meta = {}; eval { $meta = $package->meta };

    (my $plugin_name = $package) =~ s/\AScriptX:://;

    # add CONFIGURATION section
    {
        my @pod;
        last unless $meta->{conf};
        for my $conf_name (sort keys %{$meta->{conf}}) {
            my $conf_spec = $meta->{conf}{$conf_name};
            push @pod, "=head2 $conf_name\n\n";

            require Data::Sah::Normalize;
            my $nsch = Data::Sah::Normalize::normalize_schema($conf_spec->{schema});
            push @pod, "$nsch->[0]. ";
            push @pod, ($conf_spec->{req} ? "Required. " : "Optional. ");

            if (defined $conf_spec->{summary}) {
                require String::PodQuote;
                push @pod, String::PodQuote::pod_quote($conf_spec->{summary}).".";
            }
            push @pod, "\n\n";

            if ($conf_spec->{description}) {
                require Markdown::To::POD;
                my $pod = Markdown::To::POD::markdown_to_pod(
                    $conf_spec->{description});
                push @pod, $pod, "\n\n";
            }
        }
        $self->add_text_to_section(
            $document, join("", @pod), 'CONFIGURATION',
            {
                after_section => ['DESCRIPTION'],
                ignore => 1,
            });
    } # CONFIGURATION

    $self->log(["Generated POD for '%s'", $filename]);
}

sub weave_section {
    my ($self, $document, $input) = @_;

    my $filename = $input->{filename};

    return unless $filename =~ m!^lib/(.+)\.pm$!;
    my $package = $1;
    $package =~ s!/!::!g;
    return unless $package =~ /\AScriptX::/;
    $self->_process_module($document, $input, $package);
}

1;
# ABSTRACT: Plugin to use when building ScriptX::* distribution

=for Pod::Coverage weave_section

=head1 SYNOPSIS

In your F<weaver.ini>:

 [-ScriptX]


=head1 DESCRIPTION

This plugin is used when building ScriptX::* distributions. It currently does
the following:

=over

=item * Create "CONFIGURATION" POD section from the meta

=back


=head1 SEE ALSO

L<ScriptX>

L<Dist::Zilla::Plugin::ScriptX>
