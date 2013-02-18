package CSS::Packer;

use 5.008009;
use warnings;
use strict;
use Carp;
use Regexp::RegGrp;

our $VERSION        = '1.000';

our $DICTIONARY     = {
    'STRING1'   => qr~"(?>(?:(?>[^"\\]+)|\\.|\\"|\\\s)*)"~,
    'STRING2'   => qr~'(?>(?:(?>[^'\\]+)|\\.|\\'|\\\s)*)'~
};

our $WHITESPACES    = '\s+';

our $RULE           = '([^{};]+)\{([^{}]*)\}';

our $URL            = 'url\(\s*(' . $DICTIONARY->{STRING1} . '|' . $DICTIONARY->{STRING2} . '|[^\'"\s]+?)\s*\)';

our $IMPORT         = '\@import\s+(' . $DICTIONARY->{STRING1} . '|' . $DICTIONARY->{STRING2} . '|' . $URL . ')([^;]*);';

our $MEDIA          = '\@media([^{}]+)\{((?:' . $IMPORT . '|' . $RULE . '|' . $WHITESPACES . ')+)\}';

our $DECLARATION    = '((?>[^;:]+)):(?<=:)((?>[^;]*))(?:;|\s*$)';

our $COMMENT        = '(\/\*[^*]*\*+([^\/][^*]*\*+)*\/)';

our $PACKER_COMMENT = '\/\*\s*CSS::Packer\s*(\w+)\s*\*\/';

our $CHARSET        = '^(\@charset)\s+(' . $DICTIONARY->{STRING1} . '|' . $DICTIONARY->{STRING2} . ');';

# --------------------------------------------------------------------------- #

sub init {
    my $class    = shift;
    my $self    = {};

    $self->{content_value}->{reggrp_data} = [
        {
            regexp      => $DICTIONARY->{STRING1}
        },
        {
            regexp      => $DICTIONARY->{STRING2}
        },
        {
            regexp      => qr~([\w-]+)\(\s*([\w-]+)\s*\)~,
            replacement => sub {
                return $_[0]->{submatches}->[0] . '(' . $_[0]->{submatches}->[0] . ')';
            }
        },
        {
            regexp      => $WHITESPACES,
            replacement => ''
        }
    ];

    $self->{whitespaces}->{reggrp_data} = [
        {
            regexp      => $WHITESPACES,
            replacement => ''
        }
    ];

    $self->{url}->{reggrp_data} = [
        {
            regexp      => $URL,
            replacement => sub {
                my $url  = $_[0]->{submatches}->[0];

                return 'url(' . $url . ')';
            }
        }
    ];

    $self->{import}->{reggrp_data} = [
        {
            regexp      => $IMPORT,
            replacement => sub {
                my $submatches  = $_[0]->{submatches};
                my $url         = $submatches->[0];
                my $mediatype   = $submatches->[2];
                my $opts        = $_[0]->{opts} || {};

                my $compress    = _get_opt( $opts, 'compress' );

                # I don't like this, but
                # $self->{url}->{reggrp}->exec( \$url );
                # will not work. It isn't initialized jet.
                # If someone has a better idea, please let me know
                $self->_process_wrapper( 'url', \$url, $opts );

                $mediatype =~ s/^\s*|\s*$//gs;
                $mediatype =~ s/\s*,\s*/,/gsm;

                return '@import ' . $url . ( $mediatype ? ( ' ' . $mediatype ) : '' ) . ';' . ( $compress eq 'pretty' ? "\n" : '' );
            }
        }
    ];

    $self->{declaration}->{reggrp_data} = [
        {
            regexp      => $DECLARATION,
            replacement => sub {
                my $submatches  = $_[0]->{submatches};
                my $key         = $submatches->[0];
                my $value       = $submatches->[1];
                my $opts        = $_[0]->{opts} || {};

                my $compress    = _get_opt( $opts, 'compress' );

                $key    =~ s/^\s*|\s*$//gs;
                $value  =~ s/^\s*|\s*$//gs;

                if ( $key eq 'content' ) {
                    # I don't like this, but
                    # $self->{content_value}->{reggrp}->exec( \$value );
                    # will not work. It isn't initialized jet.
                    # If someone has a better idea, please let me know
                    $self->_process_wrapper( 'content_value', \$value, $opts );
                }
                else {
                    $value =~ s/\s*,\s*/,/gsm;
                    $value =~ s/\s+/ /gsm;
                }

                return '' if ( not $key or ( not $value and $value ne '0' ) );

                return $key . ':' . $value . ';' . ( $compress eq 'pretty' ? "\n" : '' );
            }
        }
    ];

    $self->{rule}->{reggrp_data} = [
        {
            regexp      => $RULE,
            replacement => sub {
                my $submatches  = $_[0]->{submatches};
                my $selector    = $submatches->[0];
                my $declaration = $submatches->[1];
                my $opts        = $_[0]->{opts} || {};

                my $compress    = _get_opt( $opts, 'compress' );

                $selector =~ s/^\s*|\s*$//gs;
                $selector =~ s/\s*,\s*/,/gsm;
                $selector =~ s/\s+/ /gsm;

                $declaration =~ s/^\s*|\s*$//gs;

                # I don't like this, but
                # $self->{declaration}->{reggrp}->exec( \$declaration );
                # will not work. It isn't initialized jet.
                # If someone has a better idea, please let me know
                $self->_process_wrapper( 'declaration', \$declaration, $opts );

                my $store = $selector . '{' . ( $compress eq 'pretty' ? "\n" : '' ) . $declaration . '}' .
                    ( $compress eq 'pretty' ? "\n" : '' );

                $store = '' unless ( $selector or $declaration );

                return $store;
            }
        }
    ];

    $self->{mediarules}->{reggrp_data} = [
        @{$self->{import}->{reggrp_data}},
        @{$self->{rule}->{reggrp_data}},
        @{$self->{whitespaces}->{reggrp_data}}
    ];

    $self->{global}->{reggrp_data} = [
        {
            regexp      => $CHARSET,
            replacement => sub {
                my $submatches  = $_[0]->{submatches};
                my $opts        = $_[0]->{opts} || {};

                return $submatches->[0] . " " . $submatches->[1] . ( $opts->{compress} eq 'pretty' ? "\n" : '' );
            }
        },
        {
            regexp      => $MEDIA,
            replacement => sub {
                my $submatches  = $_[0]->{submatches};
                my $mediatype   = $submatches->[0];
                my $mediarules  = $submatches->[1];
                my $opts        = $_[0]->{opts} || {};

                my $compress    = _get_opt( $opts, 'compress' );

                $mediatype =~ s/^\s*|\s*$//gs;
                $mediatype =~ s/\s*,\s*/,/gsm;

                # I don't like this, but
                # $self->{mediarules}->{reggrp}->exec( \$mediarules );
                # will not work. It isn't initialized jet.
                # If someone has a better idea, please let me know
                $self->_process_wrapper( 'mediarules', \$mediarules, $opts );

                return '@media ' . $mediatype . '{' . ( $compress eq 'pretty' ? "\n" : '' ) .
                    $mediarules . '}' . ( $compress eq 'pretty' ? "\n" : '' );
            }
        },
        @{$self->{mediarules}->{reggrp_data}}
    ];


    map {
        $self->{$_}->{reggrp} = Regexp::RegGrp->new(
            {
                reggrp => $self->{$_}->{reggrp_data}
            }
        );
    } ( 'whitespaces', 'url', 'import', 'declaration', 'rule', 'content_value', 'mediarules', 'global' );

    bless( $self, $class );

    return $self;
}

sub minify {
    my ( $self, $input, $opts );

    unless (
        ref( $_[0] ) and
        ref( $_[0] ) eq __PACKAGE__
    ) {
        $self = __PACKAGE__->init();

        shift( @_ ) unless ( ref( $_[0] ) );

        ( $input, $opts ) = @_;
    }
    else {
        ( $self, $input, $opts ) = @_;
    }

    if ( ref( $input ) ne 'SCALAR' ) {
        carp( 'First argument must be a scalarref!' );
        return undef;
    }

    my $css     = \'';
    my $cont    = 'void';

    if ( defined( wantarray ) ) {
        my $tmp_input = ref( $input ) ? ${$input} : $input;

        $css    = \$tmp_input;
        $cont   = 'scalar';
    }
    else {
        $css = ref( $input ) ? $input : \$input;
    }

    if ( ref( $opts ) ne 'HASH' ) {
        carp( 'Second argument must be a hashref of options! Using defaults!' ) if ( $opts );
        $opts = { compress => 'pretty', no_compress_comment => 0 };
    }
    else {
        $opts->{compress}               = grep( $opts->{compress}, ( 'minify', 'pretty' ) ) ? $opts->{compress} : 'pretty';
        $opts->{no_compress_comment}    = $opts->{no_compress_comment} ? 1 : 0;
    }

    if ( not $opts->{no_compress_comment} and ${$css} =~ /$PACKER_COMMENT/ ) {
        my $compress = $1;
        if ( $compress eq '_no_compress_' ) {
            return ( $cont eq 'scalar' ) ? ${$css} : undef;
        }

        $opts->{compress} = grep( $compress, ( 'minify', 'pretty' ) ) ? $compress : $opts->{compress};
    }

    ${$css} =~ s/$COMMENT/ /gsm;

    $self->{global}->{reggrp}->exec( $css, $opts );

    return ${$css} if ( $cont eq 'scalar' );
}

sub _process_wrapper {
    my ( $self, $reg_name, $in, $opts ) = @_;

    $self->{$reg_name}->{reggrp}->exec( $in, $opts );
}

sub _restore_wrapper {
    my ( $self, $reg_name, $in ) = @_;

    $self->{$reg_name}->{reggrp}->restore_stored( $in );
}

sub _get_opt {
    my ( $opts_hash, $opt ) = @_;

    $opts_hash  ||= {};
    $opt       ||= '';

    my $ret = '';

    $ret = $opts_hash->{$opt} if ( defined( $opts_hash->{$opt} ) );

    return $ret;
}

1;

__END__

=head1 NAME

CSS::Packer - Another CSS minifier

=head1 VERSION

Version 1.000

=head1 DESCRIPTION

A fast pure Perl CSS minifier.

=head1 SYNOPSIS

    use CSS::Packer;

    my $packer = CSS::Packer->init();

    $packer->minify( $scalarref, $opts );

To return a scalar without changing the input simply use (e.g. example 2):

    my $ret = $packer->minify( $scalarref, $opts );

For backward compatibility it is still possible to call 'minify' as a function:

    CSS::Packer::minify( $scalarref, $opts );

First argument must be a scalarref of CSS-Code.
Second argument must be a hashref of options. The only option is

=over 4

=item compress

Defines compression level. Possible values are 'minify' and 'pretty'.
Default value is 'pretty'.

'pretty' converts

    a {
    color:          black
    ;}   div

    { width:100px;
    }

to

    a{
    color:black;
    }
    div{
    width:100px;
    }

'minify' converts the same rules to

    a{color:black;}div{width:100px;}

=back

=head1 AUTHOR

Merten Falk, C<< <nevesenin at cpan.org> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-css-packer at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=CSS-Packer>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

perldoc CSS::Packer

=head1 COPYRIGHT & LICENSE

Copyright 2008 - 2011 Merten Falk, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 SEE ALSO

L<CSS::Minifier>,
L<CSS::Minifier::XS>

=cut
