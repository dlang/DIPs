#!/usr/bin/zsh

# Exit on first error
set -e

if [ -z $D ]; then
    echo "Please specify the D stdlib install path in $D"
    return 1
fi

rm -f /tmp/test.log

# Process all std files
echo "|File|Imports (unittest)|Imports (compile)|Imports (top)"
echo "|---|---|---|---|"
(
    cd $D
    for f in std/*.d std/{algorithm,container,digest,experimental,net,range,regex}/**/*.d; do
        echo "import $f;" | sed -e 's|/|.|g' -e 's/\.d;/;/' -e 's/\.package//' >/tmp/test.d
        echo -n "|$f"
        LINES1=$(dmd -o- -c -v -unittest $f 2>>/tmp/test.log | \
            grep '^import  *std\.' | wc -l)
        LINES2=$(dmd -o- -c -v $f 2>>/tmp/test.log | \
            grep '^import  *std\.' | wc -l)
        LINES3=$(dmd -o- -c -v /tmp/test.d 2>>/tmp/test.log | \
            grep '^import  *std\.' | wc -l)
        # Subtract 1 from LINES3 to discount the imported file itself
        echo "|$LINES1|$LINES2|$[LINES3-1]|"
    done | sort -t'|' --key=3 -nr
)
