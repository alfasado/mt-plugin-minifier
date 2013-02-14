<?php
function smarty_block_mthtmlcompressor ( $args, $content, &$ctx, &$repeat ) {
    if ( isset( $content ) ) {
        global $mt;
        require_once( 'outputfilter.trimwhitespace.php' );
        $content = smarty_outputfilter_trimwhitespace( $content, $mt );
        $repeat = FALSE;
        return $content;
    }
}
?>