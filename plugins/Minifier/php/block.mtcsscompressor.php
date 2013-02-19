<?php
function smarty_block_mtcsscompressor ( $args, $content, &$ctx, &$repeat ) {
    if ( isset( $content ) ) {
        if ( $args[ 'flatten_css_imports' ] ) {
            if ( $app = $ctx->stash( 'bootstrapper' ) ) {
                $root = $app->root;
                $file = $app->stash( 'file' );
                $base = $app->base();
                $dir = dirname( $file );
                $content = preg_replace( '/\r\n?/', '\n/g', $content );
                $lines = explode( "\n", $content );
                $imports = array();
                foreach ( $lines as $line ) {
                    if ( preg_match( '/^\@import/', $line ) ) {
                        array_push( $imports, $line );
                    }
                }
                foreach ( $imports as $import ) {
                    if ( preg_match( '/[\'"](.*?)[\'"]/', $import, $matches ) ) {
                        $target = $matches[ 1 ];
                        $pos = strpos( $target, '..' );
                        if ( (! $app->config( 'AllowIncludeParentDir' ) ) &&
                            $pos !== FALSE ) {
                        } else {
                            if ( preg_match( '/^http/', $target ) ) {
                                $pos = strpos( $target, $base );
                                if ( $pos === 0 ) {
                                    $in = str_replace( $base, $root, $target );
                                }
                            } elseif ( preg_match( '/^\//', $target ) ) {
                                $in = $root . $target;
                            } else {
                                $in = $dir . DIRECTORY_SEPARATOR . $target;
                            }
                            if ( $in ) {
                                $in = str_replace( '/', DIRECTORY_SEPARATOR, $in );
                                if ( file_exists( $in ) ) {
                                    $css = file_get_contents( $in );
                                    $content = str_replace( $import, $css, $content );
                                }
                            }
                        }
                    }
                }
            }
        }
        $content = preg_replace( '!/\*[^*]*\*+([^/][^*]*\*+)*/!', '', $content );
        $content = str_replace( array( "\r\n", "\r", "\n", "\t", '  ', '    ', '    ' ),
                                '', $content );
        $repeat = FALSE;
        return $content;
    }
}
?>