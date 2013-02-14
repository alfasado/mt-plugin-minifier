<?php
    $mt = MT::get_instance();
    if ( $mt->config( 'dynamic2gzip' ) ) {
        ini_set( 'zlib.output_compression', 'On' );
    }
?>