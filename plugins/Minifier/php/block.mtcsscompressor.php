<?php
function smarty_block_mtcsscompressor ( $args, $content, &$ctx, &$repeat ) {
    if ( isset( $content ) ) {
        $content = preg_replace( '!/\*[^*]*\*+([^/][^*]*\*+)*/!', '', $content );
        $content = str_replace( array( "\r\n", "\r", "\n", "\t", '  ', '    ', '    ' ),
                                '', $content );
        $repeat = FALSE;
        return $content;
    }
}
?>