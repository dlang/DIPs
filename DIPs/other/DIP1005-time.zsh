#!/usr/bin/zsh

# Exit on first error
set -e

if [ -z $D ]; then
    echo "Please specify the D stdlib install path in $D"
    return 1
fi

rm -f /tmp/test.log

T=/tmp/dmd2
DC="$T/linux/bin64/dmd -I$T/src/druntime/import -I$T/src/phobos -L-L$T/linux/lib64"
DC="dmd"

MODULES=( $(cd $D && echo std/*.d std/regex/package.d std/{algorithm,container,digest,experimental,net,range}/**/*.d ) )

function measure()
{
    F=$1
    rm -f $F
    for f in $MODULES; do
        echo "import $f;" | sed -e 's|/|.|g' -e 's/\.d;/;/' -e 's/\.package//' >/tmp/test.d
        rm -f test.o
        NOW=$(date +%s%3N)
        eval $DC -c /tmp/test.d 2>>/tmp/test.log
        ELAPSED=$[ $(date +%s%3N) - $NOW ]
        echo "$ELAPSED|$(wc -c <test.o)" >>$F
    done
}

# Process all std files
(
    cd $D
    git checkout temp || true
    measure /tmp/times_many_top_imports
    git checkout master || true
    measure /tmp/times_few_top_imports
)

rm -f /tmp/modules
for f in $MODULES; do
    echo "|$f" >>/tmp/modules
done

paste -d'|' /tmp/modules /tmp/times_many_top_imports /tmp/times_few_top_imports
