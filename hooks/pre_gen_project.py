import re
import sys

SLUG_REGEX = r'^[_a-zA-Z][_a-zA-Z0-9]+$'
project_slug = '{{ cookiecutter.project_slug }}'

if not re.match(SLUG_REGEX, project_slug):
    print(f'ERROR: {project_slug!r} is not a valid project slug!')
    print('It must start with a letter or underscore and contain only letters, numbers, and underscores.')
    sys.exit(1)
