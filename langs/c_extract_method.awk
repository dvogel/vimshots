{
    if ($1 == function_name) {
        found=1;
        print $3;
    } else if (found == 1) {
        print $3;
        exit;
    }
}

