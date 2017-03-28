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

"""Usage: recursive_delete.py -PF 3 /path/to/dir

This will recursively delete all files found in a provided directory,
This is a python implementation of ``rm -rf /path`` with the difference that it
has, built in, the ability to preserve 'n' number of files last found while
indexing the path. This also can be used in conduction with an mtime or ctime
sort. The sort mechanism is useful when attempting to clean up an existing
directory while preserving the last few created or modified files. Another
feature implemented is the ability to preserve or remove the directory
structure or any found symlinks.
"""

import argparse
import os

def arg_parser():
    """Setup argument Parsing.

    :returns: ``dict``
    """
    parser = argparse.ArgumentParser(
        usage='%(prog)s /path/to/directory/',
        description='Delete all the files in a directory',
        epilog=''
    )

    arguments = {
        'path': {
            'commands': ['path'],
            'nargs': 1,
            'help': 'Path to the directory that we want to delete all the'
                    ' files from.'
        },
        'preserve_files': {
            'commands': ['--preserve-files', '-PF'],
            'type': int,
            'default': 0,
            'metavar': '',
            'help': 'Set the number of new files to NOT delete. Notice that'
                    ' this will look at your local files and preserve the last'
                    ' "n" number of new files, Default: %(default)s'
        },
        'preserve_symlinks': {
            'commands': ['--preserve-symlinks', '-PS'],
            'action': 'store_true',
            'default': False,
            'help': 'Preserve any and all symlinks encountered in the provided'
                    ' path. Default: %(default)s'
        },
        'preserve_directories': {
            'commands': ['--preserve-directories', '-PD'],
            'action': 'store_true',
            'default': False,
            'help': 'Preserve empty directories encountered in the'
                    ' provided path., Default: %(default)s'
        },
        'sort': {
            'commands': ['--sort', '-S'],
            'choices': ['mtime', 'ctime'],
            'help': 'Sort the found files by either the "modified time" or the'
                    ' "creation time".'
        },
        'older_than': {
            'commands': ['--older-than', '-OT'],
            'type': int,
            'metavar': '',
            'help': 'Further filter the returned files by some number of hours'
                    ' older than the number provided. This only works if a'
                    ' sort by either mtime or ctime has been set,'
                    ' Default: %(default)s',
            'default': 0
        }
    }

    for argument in arguments.keys():
        _arg = arguments[argument]
        parser.add_argument(
            *_arg.pop('commands'),
            **_arg
        )

    # Return the parsed arguments as a dict
    return vars(parser.parse_args())


def _indexer(path, return_items):
    """Return a list of indexed files.

    :param path: ``str``
    :return: ``dict``
    """

    _location = os.path.realpath(
        os.path.expanduser(
            path.encode('utf8')
        )
    )

    if os.path.isdir(_location):
        r_walk = os.walk(_location)
        indexes = [(root, fls) for root, sfs, fls in r_walk]
        for path, index in indexes:
            if index:
                for file_name in index:
                    full_file_path = os.path.join(path, file_name)
                    if os.path.islink(full_file_path):
                        return_items['links'].append(full_file_path)
                    else:
                        return_items['files'].append(full_file_path)
            else:
                return_items['empty_dir'].append(path)

        return return_items
    else:
        raise SystemExit('[ %s ] is not a directory' % _location)


def get_local_files(path, sort_by=None):
    """Find all files specified in the "source" path.

    This creates a list for all of files using the full path. If `sort_by` is
    used, it must be set as a function that will be used for sorting.

    :param path: ``list``
    :param sort_by: ``object``
    """
    # Set the data structure for our indexed items
    items = {
        'path': path,
        'files': [],
        'empty_dir': [],
        'links': []
    }

    for local_path in path:
        _indexer(local_path, items)

    if sort_by is not None:
        items['files'] = [f for f in items['files'] if sort_by(f) ]
        items['files'] = sorted(items['files'], key=sort_by)

    return items


def remove_files(items, preserve_dir, preserve_sym, preserve_files=0):
    """Remove all files in a list.

    This method will iterate through the items dict and remove files,
    directories, and symlinks as instructed. The default behaviour is to remove
    all files, directories, and symlinks. To modify this behavior setting
    the `preserve_dir` or `preserve_sym` as True. If `preserve_dir` is True
    this method will remove ONLY the files in the path but will keep the
    directory structure. If `preserve_sym` is set True all symlinks will be
    preserved in as found in the path, HOWEVER, the symlink may be broken due
    to the initial file removal.


    Example items Structure:
        >>> items = {
        ...     'path': '/path/to/somewhere'
        ...     'files': ['list', 'of', 'files']
        ...     'empty_dir': ['list', 'of', 'empty', 'directories']
        ...     'links': ['list', 'of', 'found', 'symbolic', 'links']
        ... }

    :param items: ``dict``
    :param preserve_dir: ``bol``
    :param preserve_sym: ``bol``
    :param preserve_files: ``int``
    """

    for _file in items['files'][:-preserve_files]:
        os.remove(_file)

    if preserve_sym is False:
        for sym_link in items['links']:
            os.remove(sym_link)

    if preserve_dir is False:
        _new_itmes = get_local_files(items['path'], sort_by=None)
        directories = sorted(_new_itmes['empty_dir'], key=len, reverse=True)
        for empty_dir in directories:
            try:
                os.removedirs(empty_dir)
            except OSError:
                pass


def main():
    """Run the main application if running from the CLI."""
    args = arg_parser()

    sort = args.get('sort')
    if sort == 'mtime':
        return_items = get_local_files(args['path'], os.path.getmtime)
    elif sort == 'ctime':
        return_items = get_local_files(args['path'], os.path.getctime)
    else:
        return_items = get_local_files(args['path'])

    remove_files(
        return_items,
        args['preserve_directories'],
        args['preserve_symlinks'],
        args['preserve_files']
    )


if __name__ == '__main__':
    main()
