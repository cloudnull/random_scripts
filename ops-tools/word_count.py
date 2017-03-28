#!/usr/bin/env python
# =============================================================================
# Copyright [2013] [Kevin Carter]
# License Information :
# This software has no warranty, it is provided 'as is'. It is your
# responsibility to validate the behavior of the routines and its accuracy
# using the code provided. Consult the GNU General Public license for further
# details (see GNU General Public License).
# http://www.gnu.org/licenses/gpl.html
# =============================================================================
"""Usage: word_count.py unique --file /path/to/file

This will provide a simple word count on the words found within the file.
the script will filter everything that it finds and only count "alpha" words.
The script has three positional arguments that could be used;

Options:
    unique,
    all-words,
    most-used

All of these positional arguments require the ``--file`` argument which can
be used multiple times to reference multiple files.
"""

import argparse
import fileinput
import os

# Cache the returns of our works search
WORDS = {}


def word_count(files):
    """Read the lines of a file and count words.

    Saves all of the words in a dict and stores a count each time the word is
    used.

    :param files: ``list``
    """
    if not all([os.path.isfile(i) for i in files]):
        raise SystemExit('One or more files referenced does not exist.')

    # File input, uses the least amount of memory while reading a file by lines
    for line in fileinput.input(files=files):
        # Split the lines via white space
        for possible_word in line.split():
            # Make sure that the word is alpha
            if possible_word.isalpha():
                # Add the word to our cache and count it
                if possible_word in WORDS:
                    WORDS[possible_word] += 1
                else:
                    WORDS[possible_word] = 1


def arg_parser():
    """Setup argument Parsing.

    :returns: ``dict``
    """
    parser = argparse.ArgumentParser(
        usage='%(prog)s',
        description='perform a word count',
        epilog=''
    )

    meta = 'count the number of words in a file(s).'
    subpar = parser.add_subparsers(title='word count in python', metavar=meta)

    arguments = {
        'unique': {
            'help': 'get a count of unique words in a file(s).'
        },
        'all-words': {
            'help': 'get a count of all words in a file(s).'
        },
        'most-used': {
            'help': 'return the most used word in a file(s).'
        }
    }

    for argument in arguments.keys():
        _arg = arguments[argument]
        action = subpar.add_parser(
            argument,
            help=_arg.get('help')
        )
        action.set_defaults(command=argument)
        action.add_argument(
            *('--file', '-F'),
            **{
                'default': [],
                'action': 'append',
                'required': True,
                'metavar': '',
                'help': 'Path to files to look at, this can be used multiple'
                        ' times.'
            }
        )

    # Return the parsed arguments as a dict
    return vars(parser.parse_args())


if __name__ == '__main__':
    # Run the main application if running from the CLI
    args = arg_parser()
    word_count(files=args['file'])
    command = args.get('command')

    if command == 'unique':
        print('Unique words in the file(s): %d' % len(WORDS.keys()))
    elif command == 'all-words':
        print('Number of words in the file(s): %d' % sum(WORDS.values()))
    elif command == 'most-used':
        most_used_word = max(WORDS.keys(), key=WORDS.get)
        print('Most Used word in the file(s): "%s"' % most_used_word)
