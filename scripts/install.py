#!/usr/bin/env python3
"""File-level dotfile deployment with a journal and conservative rollback."""
import argparse
import datetime
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys

REPO = Path(__file__).resolve().parents[1]


def exists(path):
    return os.path.lexists(path)


def save(path, data):
    tmp = path.with_suffix('.tmp')
    tmp.write_text(json.dumps(data, indent=2) + '\n')
    tmp.replace(path)


def restore(journal):
    records = json.loads(journal.read_text())
    conflicts = []
    for record in reversed(records):
        dest, src, backup = (Path(record[k]) for k in ('dest', 'src', 'backup'))
        if record.get('retired'):
            if exists(backup):
                if exists(dest):
                    conflicts.append(str(dest))
                else:
                    backup.rename(dest)
            continue
        if dest.is_symlink() and os.readlink(dest) == str(src):
            dest.unlink()
        elif exists(dest):
            # An interrupted transaction may not yet have moved the original.
            if not exists(backup) and record['original']:
                continue
            conflicts.append(str(dest))
            continue
        if exists(backup):
            backup.rename(dest)
    if conflicts:
        raise RuntimeError('Restore preserved changed files; resolve and retry: ' + ', '.join(conflicts))


def deploy(home, dry_run):
    config = Path(os.environ.get('XDG_CONFIG_HOME', str(home / '.config')))
    state = Path(os.environ.get('XDG_STATE_HOME', str(home / '.local/state')))
    if not config.is_absolute() or not state.is_absolute():
        raise RuntimeError('XDG paths must be absolute')
    mappings = []
    for source_root, target_root in [
        (REPO / 'home', home),
        (REPO / 'config', config),
        (REPO / 'bin', home / '.local/bin'),
    ]:
        sources = source_root.glob('*') if source_root.name == 'bin' else source_root.rglob('*')
        for src in sorted(sources):
            if src.is_file():
                mappings.append((src, target_root / src.relative_to(source_root)))
    # Retire only our old symlinks, preserving personal replacements and journaling
    # the originals so the same rollback command can restore a pre-migration setup.
    retired = [
        (REPO / 'bin/desktop-launcher', home / '.local/bin/desktop-launcher'),
        (REPO / 'bin/desktop-menu', home / '.local/bin/desktop-menu'),
        (REPO / 'config/DankMaterialShell/themes/mocha.json', config / 'DankMaterialShell/themes/mocha.json'),
    ]
    retired = [(s, d) for s, d in retired if d.is_symlink() and os.readlink(d) == str(s)]
    mappings.extend(retired)
    # Refuse symlinked parent directories: otherwise a backup could modify another repo.
    for _, dest in mappings:
        for parent in dest.parents:
            if parent.is_symlink():
                raise RuntimeError(f'Symlinked parent directory needs manual migration: {parent}')
    # Niri hot reloads: deploy its entrypoint after all supporting files.
    mappings.sort(key=lambda item: item[0] == REPO / 'config/niri/config.kdl')
    changes = [(s, d) for s, d in mappings
               if (s, d) in retired or not (d.is_symlink() and os.readlink(d) == str(s))]
    for src, dest in changes:
        if (src, dest) in retired:
            print(f'Back up retired link {dest}')
        else:
            print(f'{"back up + " if exists(dest) else ""}link {dest} -> {src}')
    if dry_run or not changes:
        print('Dry run; no files changed.' if dry_run else 'Already installed.')
        return
    stamp = datetime.datetime.now().strftime('%Y%m%d-%H%M%S-%f')
    backup_root = state / 'niri-dotfiles/backups' / stamp
    backup_root.mkdir(parents=True, mode=0o700)
    journal = backup_root / 'manifest.json'
    records = []
    try:
        for index, (src, dest) in enumerate(changes):
            dest.parent.mkdir(parents=True, exist_ok=True)
            backup = backup_root / str(index)
            records.append(dict(src=str(src), dest=str(dest), backup=str(backup),
                                original=exists(dest), retired=(src, dest) in retired))
            save(journal, records)
            if exists(dest):
                dest.rename(backup)
            if (src, dest) not in retired:
                dest.symlink_to(src)
    except BaseException:
        restore(journal)
        raise
    print(f'Backup journal: {journal}')
    print(f'Rollback: {REPO}/install --restore {journal}')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--dry-run', action='store_true', help='Print file and package changes only')
    parser.add_argument('--packages', action='store_true', help='Install packages with a full pacman upgrade, then link files')
    parser.add_argument('--packages-only', action='store_true', help='Install packages without linking files')
    parser.add_argument('--restore', type=Path, metavar='MANIFEST', help='Restore a backup journal without removing packages')
    args = parser.parse_args()
    if os.geteuid() == 0:
        parser.error('Run as your desktop user; only pacman uses sudo.')
    if args.restore:
        if args.packages or args.packages_only or args.dry_run:
            parser.error('--restore cannot be combined with other options')
        restore(args.restore.expanduser().resolve())
        return
    if args.packages or args.packages_only:
        if not shutil.which('pacman'):
            parser.error('Package installation requires CachyOS or Arch Linux')
        packages = [line.split('#')[0].strip() for line in (REPO / 'packages.txt').read_text().splitlines()]
        command = ['sudo', 'pacman', '-Syu', '--needed', *filter(None, packages)]
        print(' '.join(command), flush=True)
        if not args.dry_run:
            subprocess.run(command, check=True)
    if not args.packages_only:
        if shutil.which('niri'):
            subprocess.run(['niri', 'validate', '-c', str(REPO / 'config/niri/config.kdl')], check=True)
        elif not args.dry_run:
            parser.error('Install Niri first with --packages (requires Niri >= 26.04)')
        deploy(Path.home(), args.dry_run)


if __name__ == '__main__':
    try:
        main()
    except KeyboardInterrupt:
        sys.exit('Cancelled.')
    except (RuntimeError, OSError, subprocess.CalledProcessError) as error:
        sys.exit(str(error))
