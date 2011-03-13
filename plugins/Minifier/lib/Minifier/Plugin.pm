package Minifier::Plugin;
use strict;

sub _pre_run {
    my $app = MT->instance;
    if ( $app->param( '__mode' ) eq 'save_cfg_system_general' ) {
        if ( $ENV{ SERVER_SOFTWARE } =~ /Microsoft-IIS/ ) {
            return 1;
        }
        if (! $app->user->is_superuser ) {
            $app->return_to_dashboard( permission => 1 );
        }
        if ( $app->param( 'use_minifier' ) ) {
            my $static_file_path = chomp_dir( $app->static_file_path );
            require File::Spec;
            my $htaccess = File::Spec->catfile( $static_file_path, '.htaccess' );
            my $dir = File::Spec->catdir( $static_file_path, 'minify_2' );
            if (-d $dir ) {
                if (! -f $htaccess ) {
                    my $tmpl = <<'MTML';
<IfModule mod_rewrite.c>
  RewriteEngine on
  RewriteRule ^([^?]+\.(css|js))$ <$MTStaticWebPath abs_addslash="1"$>minify_2/min/f=<$MTStaticWebPath abs_addslash="1" cut_firstslash="1"$>$1 [NC,L]
</IfModule>
MTML
                    my $data = build_tmpl( $app, $tmpl );
                    write2file( $htaccess, $data );
                }
            }
        }
    }
    return 1;
}

sub _cfg_system_general {
    my ( $cb, $app, $param, $tmpl ) = @_;
    my $plugin = MT->component( 'Minifier' );
    if ( $ENV{ SERVER_SOFTWARE } =~ /Microsoft-IIS/ ) {
        return 1;
    }
    my $static_file_path = chomp_dir( $app->static_file_path );
    my $dir = File::Spec->catdir( $static_file_path, 'minify_2' );
    if (! -d $dir ) {
        return;
    }
    my $pointer_field = $tmpl->getElementById( 'system_performance_logging' );
    my $nodeset = $tmpl->createElement( 'app:setting', { id => 'use_minifier',
                                                         label => $plugin->translate( 'Minifier' ) ,
                                                         show_label => 1,
                                                         content_class => 'field-content-text' } );
    my $innerHTML = <<MTML;
<__trans_section component="Minifier">
        <input type="checkbox" id="use_minifier" name="use_minifier"<mt:if name="use_minifier"> checked="checked"</mt:if> class="cb" /> <label for="use_minifier"><__trans phrase="Minifying JavaScript and CSS code in mt-static"></label>
</__trans_section>
MTML
    $nodeset->innerHTML( $innerHTML );
    $tmpl->insertAfter( $nodeset, $pointer_field );
    require File::Spec;
    my $htaccess = File::Spec->catfile( $static_file_path, '.htaccess' );
    if ( my $cfg = read_from_file( $htaccess ) ) {
        my $search = quotemeta( 'minify_2/min/f=' );
        if ( $cfg =~ /$search/ ) {
            $param->{ use_minifier } = 1;
        }
    }
    return 1;
}

sub _hdlr_css_compressor {
    my ( $ctx, $args, $cond ) = @_;
    my $out = _hdlr_pass_tokens( @_ );
    $out = MT->instance->translate_templatized( $out );
    require CSS::Minifier;
    $out = CSS::Minifier::minify( input => $out );
    return $out;
}

sub _hdlr_js_compressor {
    my ( $ctx, $args, $cond ) = @_;
    my $out = _hdlr_pass_tokens( @_ );
    $out = MT->instance->translate_templatized( $out );
    require JavaScript::Minifier;
    $out = JavaScript::Minifier::minify( input => $out );
    return $out;
}

sub _hdlr_pass_tokens {
    my ( $ctx, $args, $cond ) = @_;
    $ctx->stash( 'builder' )->build( $ctx, $ctx->stash( 'tokens' ), $cond );
}

sub _fltr_abs_addslash {
    my ( $text, $arg, $ctx ) = @_;
    $text = add_slash( $text );
    $text =~ s!^https{0,1}://.*?(/)!$1!;
    return $text;
}

sub _fltr_cut_firstslash {
    my ( $text, $arg, $ctx ) = @_;
    $text =~ s!^/!!;
    return $text;
}

sub add_slash {
    my $path = shift;
    return $path if $path eq '/';
    if ( $path =~ m!^https?://! ) {
        $path =~ s{/*\z}{/};
        return $path;
    }
    $path = chomp_dir( $path );
    $path .= '/';
    return $path;
}

sub build_tmpl {
    my ( $app, $tmpl, $args, $params ) = @_;
    require MT::Template;
    require MT::Builder;
    require MT::Template::Context;
    my $ctx = MT::Template::Context->new;
    my $build = MT::Builder->new;
    my $tokens = $build->compile( $ctx, $tmpl )
        or return $app->error( $app->translate(
            "Parse error: [_1]", $build->errstr ) );
    defined( my $html = $build->build( $ctx, $tokens ) )
        or return $app->error( $app->translate(
            "Build error: [_1]", $build->errstr ) );
    return $html;
}

sub chomp_dir {
    my $dir = shift;
    require File::Spec;
    my @path = File::Spec->splitdir( $dir );
    $dir = File::Spec->catdir( @path );
    return $dir;
}

sub read_from_file {
    my ( $path ) = @_;
    require MT::FileMgr;
    my $fmgr = MT::FileMgr->new( 'Local' ) or die MT::FileMgr->errstr;
    unless ( $fmgr->exists( $path ) ) {
       return '';
    }
    my $data = $fmgr->get_data( $path );
    return $data;
}

sub write2file {
    my ( $path, $data ) = @_;
    require MT::FileMgr;
    my $fmgr = MT::FileMgr->new( 'Local' ) or return 0;
    require File::Basename;
    my $dir = File::Basename::dirname( $path );
    $dir =~ s!/$!! unless $dir eq '/';
    unless ( $fmgr->exists( $dir ) ) {
        $fmgr->mkpath( $dir ) or return 0;
    }
    $fmgr->put_data( $data, "$path.new" );
    if ( $fmgr->rename( "$path.new", $path ) ) {
        if ( $fmgr->exists( $path ) ) {
            return 1;
        }
    }
    return 0;
}

1;