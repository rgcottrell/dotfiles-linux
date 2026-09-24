"""Exercise shell lifecycle and idle locking without touching the live session."""
import os
from pathlib import Path
import runpy
import tempfile
import unittest
from unittest.mock import MagicMock, patch

SESSION = Path(__file__).resolve().parents[1] / 'bin/niri-desktop-session'
AGENT = '/usr/lib/polkit-kde-authentication-agent-1'


class SessionTests(unittest.TestCase):
    def run_session(self, installed=True, failed=False):
        with tempfile.TemporaryDirectory() as directory:
            config = Path(directory) / 'config'
            launched = []
            processes = []

            def popen(command, **kwargs):
                launched.append((command, kwargs))
                process = MagicMock()
                processes.append(process)
                process.returncode = 1 if failed else 0
                process.pid = 12345
                process.poll.return_value = None
                if command == ['niri', 'msg', 'event-stream']:
                    process.poll.side_effect = [None, None, 0, 0]
                elif command[0] == 'qs' and failed:
                    process.poll.return_value = 1
                return process

            def which(name, **kwargs):
                if name == 'polkit-kde-authentication-agent-1':
                    return AGENT
                return '/usr/bin/qs' if installed else None

            with patch.dict(os.environ, XDG_RUNTIME_DIR=directory, XDG_CONFIG_HOME=str(config)), \
                 patch('shutil.which', side_effect=which), \
                 patch('subprocess.Popen', side_effect=popen), \
                 patch('signal.signal'), patch('os.killpg') as killpg, patch('time.sleep'):
                runpy.run_path(str(SESSION), run_name='__main__')
            self.assertFalse((config / 'DankMaterialShell').exists())
            return launched, processes, killpg

    def test_shell_uses_managed_config_and_own_process_group(self):
        launched, processes, killpg = self.run_session()
        self.assertEqual([cmd[0] for cmd, _ in launched], ['niri', 'swayidle', AGENT, 'qs'])
        command, kwargs = launched[-1]
        self.assertTrue(command[2].endswith('/config/quickshell/desktop'))
        self.assertIn('--no-duplicate', command)
        self.assertTrue(kwargs['start_new_session'])
        killpg.assert_called()
        for process in processes:
            process.wait.assert_called()
        processes[1].terminate.assert_called_once()
        processes[2].terminate.assert_called_once()

    def test_missing_shell_keeps_idle_and_authentication(self):
        launched, _, _ = self.run_session(installed=False)
        self.assertEqual([cmd[0] for cmd, _ in launched], ['niri', 'swayidle', AGENT])

    def test_shell_exit_keeps_idle_without_starting_another_shell(self):
        launched, processes, killpg = self.run_session(failed=True)
        self.assertEqual([cmd[0] for cmd, _ in launched], ['niri', 'swayidle', AGENT, 'qs'])
        killpg.assert_called()
        processes[1].terminate.assert_called_once()


if __name__ == '__main__':
    unittest.main()
