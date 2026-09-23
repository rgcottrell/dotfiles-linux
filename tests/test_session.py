"""Verify DMS startup and failure handling without touching the live session."""
import json
import os
from pathlib import Path
import runpy
import tempfile
import unittest
from unittest.mock import MagicMock, patch

SESSION = Path(__file__).resolve().parents[1] / 'bin/niri-desktop-session'


class SessionTests(unittest.TestCase):
    def run_session(self, installed=True, failed=False, classic=False, existing=None):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            config = root / 'config'
            (config / 'niri').mkdir(parents=True)
            settings = config / 'DankMaterialShell/settings.json'
            if classic:
                (config / 'niri/classic-desktop').touch()
            if existing is not None:
                settings.parent.mkdir()
                settings.write_text(json.dumps(existing))
            launched = []

            def popen(command, **kwargs):
                launched.append(command)
                process = MagicMock()
                process.returncode = 1 if failed else 0
                process.pid = 12345
                process.poll.return_value = None
                if command == ['niri', 'msg', 'event-stream']:
                    # One loop iteration, including its reap, then disconnect.
                    process.poll.side_effect = [None, None, 0, 0]
                elif command == ['dms', 'run'] and failed:
                    process.poll.return_value = 1
                return process

            with patch.dict(os.environ, XDG_RUNTIME_DIR=directory, XDG_CONFIG_HOME=str(config)), \
                 patch('shutil.which', return_value='/usr/bin/dms' if installed else None), \
                 patch('subprocess.Popen', side_effect=popen), \
                 patch('signal.signal'), patch('os.killpg'), patch('time.sleep'):
                runpy.run_path(str(SESSION), run_name='__main__')
            return launched, json.loads(settings.read_text()) if settings.exists() else None

    def test_dms_replaces_classic_helpers_and_seeds_settings(self):
        commands, settings = self.run_session()
        self.assertIn(['dms', 'run'], commands)
        self.assertNotIn(['mako'], commands)
        self.assertNotIn(['waybar'], commands)
        self.assertTrue(any(command[0] == 'swayidle' for command in commands))
        self.assertEqual(settings['currentThemeName'], 'custom')
        self.assertFalse(settings['runDmsMatugenTemplates'])

    def test_missing_package_keeps_idle_without_fallback(self):
        commands, settings = self.run_session(installed=False)
        self.assertEqual([command[0] for command in commands], ['niri', 'swayidle'])
        self.assertIsNone(settings)

    def test_obsolete_marker_does_not_disable_dms(self):
        commands, _ = self.run_session(classic=True)
        self.assertIn(['dms', 'run'], commands)
        self.assertNotIn(['waybar'], commands)

    def test_dms_exit_does_not_start_fallback(self):
        commands, _ = self.run_session(failed=True)
        self.assertIn(['dms', 'run'], commands)
        self.assertEqual([command[0] for command in commands], ['niri', 'swayidle', 'dms'])

    def test_existing_settings_preserved(self):
        original = {'currentThemeName': 'user-theme', 'clockFormat': '12h'}
        _, settings = self.run_session(existing=original)
        self.assertEqual(settings, original)


if __name__ == '__main__':
    unittest.main()
