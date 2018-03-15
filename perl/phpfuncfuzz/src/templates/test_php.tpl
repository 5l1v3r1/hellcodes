<?php
    if(isset($_GET["arg1"])) {
        $log_file = "{{OUTPUT_FILE}}";
        $result = {{FUNCTION}};
        $function_eval = "{{EFUNCTION}}";
        
        for($i = 1; $i <= 9; $i++) {
            if(isset($_GET["arg$i"])) {
                $function_eval = str_replace("\$_GET[\"arg$i\"]", $_GET["arg$i"], $function_eval);
            }
        }
        
        $efunction_eval = str_replace("'", "\\x27", $function_eval);
        $result2 =  exec("php -r '$efunction_eval;'");
        
        $output = "[query]: " . $_SERVER['QUERY_STRING'] . "\n[call]: " . "{{EFUNCTION}} => $function_eval\n[result]: " . $result2 . "\n[value]: " . $result . "\n\n";
        
        file_put_contents($log_file, $output, FILE_APPEND);
    }
?>

