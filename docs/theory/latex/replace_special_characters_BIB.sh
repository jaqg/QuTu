#!/bin/bash

BIB_FILE="TFG.bib"
TEMP_FILE=$(mktemp)

# Characters to replace
declare -A replacements=(
    #
    # Math
    #
    ["\${{"]="$"
    ["}}\$"]="$"
    #
    # UTF-8 characters
    #
    # ["á"]="\\'{a}"
    # ["é"]="\\'{e}"
    # ["í"]="\\'{i}"
    # ["ó"]="\\'{o}"
    # ["ø"]="\\o"
    # ["ö"]="\\\"o"
    # ["ú"]="\\'{u}"
    # ["Á"]="\\'{A}"
    # ["É"]="\\'{E}"
    # ["Í"]="\\'{I}"
    # ["Ó"]="\\'{O}"
    # ["Ú"]="\\'{U}"
    # ["ñ"]="\\~{n}"
    # ["Ñ"]="\\~{N}"
    # ["ü"]="\\\"u"
    # ["Ü"]="\\\"U"
    # ["ß"]="\\ss{}"
)

# Read the .bib file
while IFS= read -r line
do
	# Replace the special characters
    for key in "${!replacements[@]}"; do
        line=${line//"$key"/${replacements[$key]}}
    done
    echo "$line" >> "$TEMP_FILE"
done < "$BIB_FILE"

# Update .bib file
mv "$TEMP_FILE" "$BIB_FILE"

echo "Replacement on $BIB_FILE done correctly."
