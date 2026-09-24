"""Offline lifecycle regression tests against installed feature assets."""
import json
import os
import pathlib
import shutil
import subprocess
import tempfile
import unittest

ASSETS = pathlib.Path('/usr/local/share/org-features')

class RuntimeTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='org-feature-tests-')
        self.root = pathlib.Path(self.temp.name)
        self.home = self.root / 'home'
        self.workspace = self.root / 'workspace with spaces'
        self.config = self.workspace / 'deployment config'
        self.profiles = self.config / 'profiles'
        self.home.mkdir()
        self.workspace.mkdir()
        self.profiles.mkdir(parents=True)
        self.env = dict(os.environ, HOME=str(self.home), ORG_DEVCONTAINER_DIR=str(self.config), CONFIGURED_PROFILES='', CHAT_AUTOSTART='0',
                        SHELL_COMPLETIONS_PREFIX=str(self.root / 'completions'))
        self.addCleanup(self.temp.cleanup)

    def hook(self, feature, phase='postcreate'):
        return subprocess.run(['bash', str(ASSETS / feature / (phase + '.sh'))],
                              cwd=self.workspace, env=self.env, capture_output=True, text=True, check=True)

    def test_repeat_create_is_idempotent(self):
        for feature in ['claude', 'codex', 'grok', 'herdr', 'opencode', 'pi', 'chat', 'bedrock',
                        'shell-history', 'shell-completions']:
            with self.subTest(feature=feature):
                self.hook(feature)
                self.hook(feature)
        for path in ['.claude', '.codex', '.grok', '.pi', '.config/herdr', '.local/share/opencode']:
            self.assertTrue((self.home / path).is_symlink(), path)
        self.hook('chat', 'poststart')
        self.hook('pure-prompt', 'poststart')

    def test_profiles_from_environment_without_env_file(self):
        self.env['CONFIGURED_PROFILES'] = 'first,second'
        for name, model in [('first', 'one'), ('second', 'two')]:
            folder = self.profiles / name
            folder.mkdir()
            (folder / 'litellm.json').write_text(json.dumps({'model_list': [{'model_name': model}]}))
            (folder / 'claude.json').write_text(json.dumps({'env': {'MODEL': model}}))
        self.hook('chat')
        config = json.loads((self.home / '.config/litellm/config.yaml').read_text())
        self.assertEqual([m['model_name'] for m in config['model_list']], ['one', 'two'])
        self.hook('claude')
        settings = json.loads((self.home / '.claude/settings.json').read_text())
        self.assertEqual(settings['env']['MODEL'], 'two')

    def test_legacy_env_file_crlf(self):
        self.env.pop('CONFIGURED_PROFILES')
        (self.config / 'devcontainer.env').write_bytes(b'CONFIGURED_PROFILES=sample\r\n')
        folder = self.profiles / 'sample'
        folder.mkdir()
        (folder / 'models.json').write_text('{"providers": {"example": {"models": []}}}')
        self.hook('pi')
        self.assertTrue((self.home / '.pi/agent/models.json').exists())

    def test_launcher_resolves_installed_assets_from_path(self):
        self.hook('chat')
        launcher = self.home / '.local/bin/start_chat_stack'
        self.assertFalse(launcher.is_symlink())
        self.assertIn(str(ASSETS / 'chat/supervisord/start.sh'), launcher.read_text())
        subprocess.run([str(launcher)], cwd=self.workspace, env=self.env, check=True)

    def test_existing_state_survives_rebuild(self):
        self.hook('grok')
        marker = self.home / '.grok/session.json'
        marker.write_text('{"saved": true}')
        self.hook('grok')
        self.assertEqual(marker.read_text(), '{"saved": true}')
        self.assertEqual(os.readlink(self.home / '.grok/bin/grok'), '/usr/local/lib/org-features/grok/grok')

    def test_fresh_home_reuses_existing_volume(self):
        self.hook('codex')
        (self.home / '.codex/auth.json').write_text('{"test": "retained"}')
        saved_data = self.home / '.data'
        fresh_home = self.root / 'rebuilt-home'
        fresh_home.mkdir()
        (fresh_home / '.data').symlink_to(saved_data, target_is_directory=True)
        self.env['HOME'] = str(fresh_home)
        self.hook('codex')
        self.assertEqual((fresh_home / '.codex/auth.json').read_text(), '{"test": "retained"}')

    def test_empty_environment_overrides_legacy_selector(self):
        (self.config / 'devcontainer.env').write_text('CONFIGURED_PROFILES=sample\n')
        folder = self.profiles / 'sample'
        folder.mkdir()
        (folder / 'models.json').write_text('{"providers": {"example": {"models": []}}}')
        self.hook('pi')
        self.assertFalse((self.home / '.pi/agent/models.json').exists())

    def test_bedrock_is_read_only(self):
        self.env['CONFIGURED_PROFILES'] = 'aws'
        self.env['AWS_REGION'] = 'us-east-1'
        bin_dir = self.home / '.local/bin'
        bin_dir.mkdir(parents=True)
        aws = bin_dir / 'aws'
        aws.write_text('#!/bin/bash\n[ "$1 $2" = "bedrock get-account-data-retention" ] || exit 99\necho none\n')
        aws.chmod(0o755)
        result = self.hook('bedrock')
        self.assertIn('(unchanged)', result.stdout)

    def test_herdr_skill_uses_bundled_release(self):
        self.hook('herdr')
        self.hook('claude')
        bin_dir = self.home / '.local/bin'
        bin_dir.mkdir(parents=True, exist_ok=True)
        for name in ['herdr', 'claude', 'codex']:
            binary = bin_dir / name
            binary.write_text('#!/bin/bash\nexit 0\n')
            binary.chmod(0o755)
        self.hook('herdr', 'poststart')
        expected = (ASSETS / 'herdr/herdr-skill.md').read_text()
        self.assertEqual((self.home / '.claude/skills/herdr/SKILL.md').read_text(), expected)
        self.assertEqual((self.home / '.agents/skills/herdr/SKILL.md').read_text(), expected)

    def test_shell_history_seeds_volume_once(self):
        (self.home / '.zsh_history').write_text(': 1:0;from-image\n')
        self.hook('shell-history')
        saved = self.home / '.data/shell-history/.zsh_history'
        self.assertEqual(saved.read_text(), ': 1:0;from-image\n')
        saved.write_text(': 2:0;from-volume\n')
        self.hook('shell-history')
        self.assertEqual(saved.read_text(), ': 2:0;from-volume\n')
        saved.write_text('')
        self.hook('shell-history')
        self.assertEqual(saved.read_text(), '')
        self.assertTrue((self.home / '.data/shell-history/.bash_history').exists())

    def test_shell_completions_writes_valid_and_skips_invalid(self):
        bin_dir = self.home / 'bin'
        bin_dir.mkdir()
        for name, zsh in [('goodcli', '#compdef goodcli'), ('badcli', 'not a completion')]:
            cli = bin_dir / name
            cli.write_text(f'#!/bin/bash\n[ "$1" = completion ] || exit 2\n'
                           f'[ "$2" = zsh ] && echo "{zsh}" || echo "complete -W run {name}"\n')
            cli.chmod(0o755)
        self.env['PATH'] = f"{bin_dir}:{self.env['PATH']}"
        result = subprocess.run(['bash', str(ASSETS / 'shell-completions/install-completions.sh'),
                                 'goodcli', 'badcli', 'absentcli'],
                                env=self.env, capture_output=True, text=True)
        self.assertEqual(result.returncode, 1)
        prefix = self.root / 'completions'
        self.assertEqual((prefix / 'zsh/site-functions/_goodcli').read_text(), '#compdef goodcli\n')
        self.assertTrue((prefix / 'bash-completion/completions/goodcli').exists())
        self.assertTrue((prefix / 'bash-completion/completions/badcli').exists())
        self.assertFalse((prefix / 'zsh/site-functions/_badcli').exists())
        self.assertFalse((prefix / 'zsh/site-functions/_absentcli').exists())
        self.assertIn("'badcli' did not emit a zsh completion", result.stderr)

    def test_shell_history_custom_root_owned_directory(self):
        # Copy installed assets so changing this test's options does not affect
        # the feature installed in the container or any other test.
        assets = self.root / 'history-assets'
        shutil.copytree(ASSETS / 'shell-history', assets)
        mount = self.root / 'root-owned-volume'
        subprocess.run(['sudo', '-n', 'install', '-d', '-o', 'root', '-g', 'root',
                        '-m', '755', str(mount)], check=True)
        for directory in [mount / 'nested/history', mount]:
            with self.subTest(directory=directory):
                (assets / 'options.env').write_text(f'DIRECTORY={directory}\n')
                subprocess.run(['bash', str(assets / 'postcreate.sh')], env=self.env,
                               capture_output=True, text=True, check=True)
                self.assertEqual(directory.stat().st_uid, os.getuid())
                self.assertTrue((directory / '.bash_history').exists())
                self.assertTrue((directory / '.zsh_history').exists())
        self.assertFalse((self.home / '.data').exists())
        # Preparing a nested destination must not recursively chown its parents.
        self.assertEqual((mount / 'nested').stat().st_uid, 0)
        subprocess.run(['sudo', '-n', 'chown', '-R', str(os.getuid()), str(mount)], check=True)

    def test_plain_zsh_writes_history_before_exit(self):
        self.hook('shell-history')
        script = f'''source {ASSETS}/shell-history/history.sh
print -r -- HISTORY_PERSISTENCE_MARKER
grep -qx 'print -r -- HISTORY_PERSISTENCE_MARKER' "$HISTFILE"; result=$?; unset HISTFILE; exit "$result"
'''
        result = subprocess.run(['zsh', '-dfi'], input=script, env=self.env,
                                capture_output=True, text=True, timeout=15)
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_zsh_preserves_configured_limits_on_repeat_source(self):
        self.hook('shell-history')
        result = subprocess.run(['zsh', '-dfc', f'''
HISTSIZE=1234; SAVEHIST=567
source {ASSETS}/shell-history/history.sh
[[ $HISTSIZE == 1234 && $SAVEHIST == 567 ]] || exit 1
SAVEHIST=0
source {ASSETS}/shell-history/history.sh
[[ $HISTSIZE == 1234 && $SAVEHIST == 0 ]]
'''], env=self.env, capture_output=True, text=True, timeout=15)
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_bash_prompt_hooks_keep_exit_status_and_history(self):
        self.hook('shell-history')
        for prompt in [
            "PROMPT_COMMAND='observe_status'",
            "PROMPT_COMMAND=(observe_status 'printf \"SECOND_HOOK\\n\"')",
        ]:
            with self.subTest(prompt=prompt):
                script = f'''observe_status() {{ printf 'HOOK_STATUS=%s\\n' "$?"; }}
{prompt}
source {ASSETS}/shell-history/history.sh
source {ASSETS}/shell-history/history.sh
false
grep -qx false "$HISTFILE"; result=$?; unset HISTFILE; exit "$result"
'''
                result = subprocess.run(['bash', '--noprofile', '--norc', '-i'],
                                        input=script, env=self.env, capture_output=True,
                                        text=True, timeout=15)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(result.stdout.count('HOOK_STATUS=1\n'), 1, result.stdout)
                if '=(' in prompt:
                    self.assertIn('SECOND_HOOK\n', result.stdout)

if __name__ == '__main__':
    unittest.main(verbosity=2)
