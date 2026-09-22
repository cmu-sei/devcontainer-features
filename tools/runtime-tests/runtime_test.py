"""Offline lifecycle regression tests against installed feature assets."""
import json
import os
import pathlib
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
        self.env = dict(os.environ, HOME=str(self.home), ORG_DEVCONTAINER_DIR=str(self.config), CONFIGURED_PROFILES='', CHAT_AUTOSTART='0')
        self.addCleanup(self.temp.cleanup)

    def hook(self, feature, phase='postcreate'):
        return subprocess.run(['bash', str(ASSETS / feature / (phase + '.sh'))],
                              cwd=self.workspace, env=self.env, capture_output=True, text=True, check=True)

    def test_repeat_create_is_idempotent(self):
        for feature in ['claude', 'codex', 'grok', 'herdr', 'opencode', 'pi', 'chat', 'bedrock']:
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

if __name__ == '__main__':
    unittest.main(verbosity=2)
