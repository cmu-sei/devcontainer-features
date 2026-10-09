"""Offline lifecycle regression tests against installed feature assets."""
import json
import os
import pathlib
import shutil
import subprocess
import tempfile
import time
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
        self.env = dict(os.environ, HOME=str(self.home), ORG_DEVCONTAINER_DIR=str(self.config), CONFIGURED_PROFILES='', CHAT_AUTOSTART='0', ORG_FEATURES_AUTO_UPDATE='false',
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

    def test_claude_bedrock_option(self):
        # The option leaves a build-time marker in the installed assets; use a copy.
        assets = self.root / 'claude-assets'
        shutil.copytree(ASSETS / 'claude', assets)
        (assets / 'bedrock-enabled').touch()
        subprocess.run(['bash', str(assets / 'postcreate.sh')], cwd=self.workspace, env=self.env, check=True)
        env = json.loads((self.home / '.claude/settings.json').read_text())['env']
        self.assertEqual(env['CLAUDE_CODE_USE_BEDROCK'], '1')
        self.assertNotIn('ANTHROPIC_DEFAULT_OPUS_MODEL', env)
        # A value in the container environment wins over the option.
        self.env['CLAUDE_CODE_USE_BEDROCK'] = '0'
        (self.home / '.claude/settings.json').write_text('{}')
        subprocess.run(['bash', str(assets / 'postcreate.sh')], cwd=self.workspace, env=self.env, check=True)
        env = json.loads((self.home / '.claude/settings.json').read_text()).get('env', {})
        self.assertNotIn('CLAUDE_CODE_USE_BEDROCK', env)

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

    def codex_package(self, codex_home, version):
        # Mirror the official installer: absolute links through ~/.codex.
        root = codex_home / 'packages/standalone'
        binary = root / 'releases' / version / 'bin/codex'
        binary.parent.mkdir(parents=True)
        binary.write_text(f'#!/bin/bash\necho "codex-cli {version}"\n')
        binary.chmod(0o755)
        (root / 'current').symlink_to(self.home / '.codex/packages/standalone/releases' / version)
        launcher = self.home / '.local/bin/codex'
        launcher.parent.mkdir(parents=True, exist_ok=True)
        launcher.unlink(missing_ok=True)
        launcher.symlink_to(self.home / '.codex/packages/standalone/current/bin/codex')

    def assert_codex_version(self, version):
        result = subprocess.run([str(self.home / '.local/bin/codex')], env=self.env,
                                capture_output=True, text=True, check=True)
        self.assertEqual(result.stdout.strip(), f'codex-cli {version}')
        releases = self.home / '.data/codex/packages/standalone/releases'
        self.assertEqual([p.name for p in releases.iterdir()], [version])

    def test_codex_seeds_empty_volume_and_repeats(self):
        self.codex_package(self.home / '.codex', '1.2.3')
        for _ in range(2):
            self.hook('codex')
            self.assert_codex_version('1.2.3')

    def test_codex_image_package_replaces_saved_releases(self):
        saved = self.home / '.data/codex'
        self.codex_package(saved, '0.0.1')
        (saved / 'auth.json').write_text('{"test": "retained"}')
        # The app-server socket link from before ~/.codex moved onto the volume.
        stale = saved / 'app-server-control/app-server-control.sock'
        stale.parent.mkdir()
        stale.symlink_to('/tmp/codex-daemon-old-container/socket')
        # Dangling user links, even into /tmp, must survive.
        user_links = [saved / 'AGENTS.md', saved / 'scratch']
        user_links[0].symlink_to('/opt/dotfiles-not-yet-installed/AGENTS.md')
        user_links[1].symlink_to('/tmp/missing')
        self.codex_package(self.home / '.codex', '1.2.3')
        self.hook('codex')
        self.assert_codex_version('1.2.3')
        self.assertEqual((self.home / '.codex/auth.json').read_text(), '{"test": "retained"}')
        self.assertFalse(stale.is_symlink())
        for link in user_links:
            self.assertTrue(link.is_symlink(), link)

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

    def test_herdr_skill_comes_from_installed_binary(self):
        self.hook('herdr')
        self.hook('claude')
        bin_dir = self.home / '.local/bin'
        bin_dir.mkdir(parents=True, exist_ok=True)
        for name in ['herdr', 'claude', 'codex']:
            binary = bin_dir / name
            binary.write_text('#!/bin/bash\nexit 0\n')
            binary.chmod(0o755)
        (bin_dir / 'herdr').write_text('#!/bin/bash\n[ "$1" = --skill ] && echo "herdr skill"\nexit 0\n')
        self.hook('herdr', 'poststart')
        expected = 'herdr skill\n'
        self.assertEqual((self.home / '.claude/skills/herdr/SKILL.md').read_text(), expected)
        self.assertEqual((self.home / '.agents/skills/herdr/SKILL.md').read_text(), expected)

    def test_poststart_updates_in_background(self):
        bin_dir = self.home / '.local/bin'
        bin_dir.mkdir(parents=True)
        marker = self.root / 'updated'
        (bin_dir / 'codex').write_text(f'#!/bin/bash\n[ "$*" = update ] && sleep 1 && touch "{marker}"\n')
        (bin_dir / 'codex').chmod(0o755)
        log = self.home / '.cache/org-features/codex-update.log'
        self.hook('codex', 'poststart')
        self.assertFalse(log.exists())
        self.env['ORG_FEATURES_AUTO_UPDATE'] = 'true'
        self.hook('codex', 'poststart')
        # The hook returns before the updater finishes.
        self.assertFalse(marker.exists())
        for _ in range(100):
            if marker.exists():
                break
            time.sleep(0.1)
        self.assertTrue(marker.exists())

    def test_grok_update_prunes_unused_downloads(self):
        self.hook('grok')
        bin_dir = self.home / '.local/bin'
        bin_dir.mkdir(parents=True)
        (bin_dir / 'grok').write_text('#!/bin/bash\nexit 0\n')
        (bin_dir / 'grok').chmod(0o755)
        downloads = self.home / '.grok/downloads'
        downloads.mkdir()
        for name in ['grok-linux-x86_64', 'grok-1.0.50-linux-x86_64']:
            (downloads / name).write_text(name)
        for link in ['grok', 'agent']:
            path = self.home / '.grok/bin' / link
            path.unlink(missing_ok=True)
            path.symlink_to('../downloads/grok-1.0.50-linux-x86_64')
        self.hook('grok', 'self-update')
        self.assertEqual([p.name for p in downloads.iterdir()], ['grok-1.0.50-linux-x86_64'])

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

    def playwright_assets(self, options):
        # A private copy, so these options leave the installed feature untouched.
        assets = self.root / 'playwright-assets'
        if not assets.exists():
            shutil.copytree(ASSETS / 'playwright', assets)
        (assets / 'options.env').write_text(options)
        return assets

    def test_playwright_cache_moves_to_volume_once(self):
        assets = self.playwright_assets('BROWSERS=none\nTRUSTLOCALCAS=false\n')
        cache = self.home / '.cache/ms-playwright'
        (cache / 'chromium-1').mkdir(parents=True)
        (cache / 'chromium-1/marker').write_text('seeded')
        for _ in range(2):
            subprocess.run(['bash', str(assets / 'postcreate.sh')], env=self.env,
                           capture_output=True, text=True, check=True)
        self.assertEqual(os.readlink(cache), str(self.home / '.data/playwright'))
        self.assertEqual((cache / 'chromium-1/marker').read_text(), 'seeded')

    def test_playwright_respects_relocated_cache(self):
        assets = self.playwright_assets('BROWSERS=none\nTRUSTLOCALCAS=false\n')
        cache = self.home / '.cache/ms-playwright'
        cache.mkdir(parents=True)
        self.env['PLAYWRIGHT_BROWSERS_PATH'] = str(self.root / 'browsers')
        subprocess.run(['bash', str(assets / 'postcreate.sh')], env=self.env,
                       capture_output=True, text=True, check=True)
        self.assertFalse(cache.is_symlink())
        self.assertFalse((self.home / '.data/playwright').exists())

    def test_playwright_seeds_default_browser_once(self):
        # Offline, the download itself fails; the hook warns and still configures the CLI.
        assets = self.playwright_assets('BROWSERS=firefox,chromium\nTRUSTLOCALCAS=false\n')
        config = self.home / '.playwright/cli.config.json'
        subprocess.run(['bash', str(assets / 'postcreate.sh')], env=self.env,
                       capture_output=True, text=True, check=True)
        self.assertEqual(json.loads(config.read_text())['browser']['browserName'], 'firefox')
        config.write_text('{"browser": {"browserName": "webkit"}, "outputDir": "out"}')
        subprocess.run(['bash', str(assets / 'postcreate.sh')], env=self.env,
                       capture_output=True, text=True, check=True)
        self.assertEqual(json.loads(config.read_text()),
                         {'browser': {'browserName': 'webkit'}, 'outputDir': 'out'})

    def test_playwright_trust_is_optional(self):
        assets = self.playwright_assets('TRUSTLOCALCAS=false\n')
        subprocess.run(['bash', str(assets / 'poststart.sh')], env=self.env,
                       capture_output=True, text=True, check=True)
        self.assertFalse((self.home / '.pki').exists())

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
