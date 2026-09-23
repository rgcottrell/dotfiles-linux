"""Exercise data-preserving deployment and rollback in disposable homes."""
import importlib.util
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location('installer', Path(__file__).resolve().parents[1] / 'scripts/install.py')
installer = importlib.util.module_from_spec(spec)
spec.loader.exec_module(installer)


class InstallerTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.home = self.root / 'home'
        self.repo = self.root / 'repo'
        self.config = self.home / '.config'
        self.state = self.home / '.local/state'
        (self.repo / 'config/app').mkdir(parents=True)
        (self.repo / 'bin').mkdir()
        (self.repo / 'config/app/settings').write_text('managed')
        (self.repo / 'bin/helper').write_text('helper')
        (self.config / 'app').mkdir(parents=True)
        self.dest = self.config / 'app/settings'
        self.dest.write_text('original')
        self.env = patch.dict(os.environ, XDG_CONFIG_HOME=str(self.config), XDG_STATE_HOME=str(self.state))
        self.env.start()
        self.addCleanup(self.env.stop)
        self.repo_patch = patch.object(installer, 'REPO', self.repo)
        self.repo_patch.start()
        self.addCleanup(self.repo_patch.stop)

    def journals(self):
        return list(self.state.glob('niri-dotfiles/backups/*/manifest.json'))

    def test_dry_run_does_not_write(self):
        installer.deploy(self.home, True)
        self.assertEqual(self.dest.read_text(), 'original')
        self.assertFalse(self.state.exists())
        self.assertFalse((self.home / '.local/bin').exists())

    def test_repeat_and_restore(self):
        unrelated = self.config / 'app/other'
        unrelated.write_text('keep')
        installer.deploy(self.home, False)
        self.assertTrue(self.dest.is_symlink())
        installer.deploy(self.home, False)
        self.assertEqual(len(self.journals()), 1)
        installer.restore(self.journals()[0])
        self.assertEqual(self.dest.read_text(), 'original')
        self.assertFalse(self.dest.is_symlink())
        self.assertFalse((self.home / '.local/bin/helper').exists())
        self.assertEqual(unrelated.read_text(), 'keep')
        installer.restore(self.journals()[0])
        self.assertEqual(self.dest.read_text(), 'original')

    def test_home_dotfiles_repeat_and_restore_with_xdg_paths(self):
        (self.repo / 'home').mkdir()
        source = self.repo / 'home/.bashrc'
        source.write_text('managed shell config')
        dest = self.home / '.bashrc'
        dest.write_text('original shell config')
        history = self.home / '.bash_history'
        history.write_text('local history')
        installer.deploy(self.home, True)
        self.assertEqual(dest.read_text(), 'original shell config')
        installer.deploy(self.home, False)
        self.assertTrue(dest.is_symlink())
        self.assertEqual(dest.resolve(), source)
        self.assertFalse((self.config / '.bashrc').exists())
        installer.deploy(self.home, False)
        self.assertEqual(len(self.journals()), 1)
        installer.restore(self.journals()[0])
        self.assertFalse(dest.is_symlink())
        self.assertEqual(dest.read_text(), 'original shell config')
        self.assertEqual(history.read_text(), 'local history')

    def test_restore_preserves_independent_changes(self):
        installer.deploy(self.home, False)
        self.dest.unlink()
        self.dest.write_text('new personal config')
        with self.assertRaises(RuntimeError):
            installer.restore(self.journals()[0])
        self.assertEqual(self.dest.read_text(), 'new personal config')

    def test_broken_symlink_preserved(self):
        self.dest.unlink()
        self.dest.symlink_to('missing-original')
        installer.deploy(self.home, False)
        installer.restore(self.journals()[0])
        self.assertEqual(os.readlink(self.dest), 'missing-original')

    def test_symlinked_parent_refused(self):
        target = self.root / 'external'
        (self.config / 'app').rename(target)
        (self.config / 'app').symlink_to(target)
        with self.assertRaises(RuntimeError):
            installer.deploy(self.home, False)
        self.assertEqual((target / 'settings').read_text(), 'original')

    def test_link_failure_rolls_back(self):
        with patch.object(Path, 'symlink_to', side_effect=OSError('injected failure')):
            with self.assertRaises(OSError):
                installer.deploy(self.home, False)
        self.assertEqual(self.dest.read_text(), 'original')
        self.assertFalse(self.dest.is_symlink())


if __name__ == '__main__':
    unittest.main()
