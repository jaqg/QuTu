import re

def check_bib_file(filepath):
    with open(filepath, 'r', encoding='utf-8') as file:
        content = file.read()

    # Regular expression patterns to check
    entry_pattern = re.compile(r'@\w+\{[^@]+\}')
    key_pattern = re.compile(r'@\w+\{([^,]+),')
    field_pattern = re.compile(r'\s*(\w+)\s*=\s*[\{"]([^"}]+)[\}"],?', re.DOTALL)

    entries = entry_pattern.findall(content)
    errors = []

    for entry in entries:
        key_match = key_pattern.search(entry)
        if not key_match:
            errors.append(f"Invalid entry key in: {entry[:50]}")
            continue

        key = key_match.group(1).strip()
        fields = field_pattern.findall(entry)

        if not fields:
            errors.append(f"No fields found in entry: {key}")
            continue

        for field, value in fields:
            if not field.strip() or not value.strip():
                errors.append(f"Empty field or value in entry: {key}")

    return errors

# Check the bib file
errors = check_bib_file('./TFM.bib')

if errors:
    print("Errors found in the BibTeX file:")
    for error in errors:
        print(f"  - {error}")
else:
    print("No errors found in the BibTeX file.")
