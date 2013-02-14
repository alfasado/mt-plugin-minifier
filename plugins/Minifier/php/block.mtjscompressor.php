<?php
function smarty_block_mtjscompressor ( $args, $content, &$ctx, &$repeat ) {
    if ( isset( $content ) ) {
        $p = array(
              "/[\r\n]+/",
              "/^[\s\t]*\/\/.+$/m",
              "/\/\*.+?\*\//s",
              "/([\{\(\[,;=])\n+/",
              "/[\s\t]*([\{\(\[,;=\+\*-<>\|\&\?\:!])[\s\t]*/",
              "/\n\}/",
              "/^[\s\t]+/m",
              "/[\s\t]+$/m",
              "/[\s\t]{2,}/",
            );
        $r = array ( "\n", "", "", "$1", "$1", "}", "", "", "", );
        do { $content = preg_replace( $p, $r, $content ); }
            while( $content != preg_replace( $p, $r, $content ) );
        $repeat = FALSE;
        return $content;
    }
}
?>