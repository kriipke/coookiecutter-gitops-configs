import subprocess

INIT_GIT = '{{ cookiecutter.init_git }}'.strip().lower() in ('true', 'yes', '1')
BRANCH = '{{ cookiecutter.repo_appsets_branch }}'.strip() or 'main'


def run(*args):
    subprocess.run(args, check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


def main():
    if not INIT_GIT:
        return
    try:
        run('git', 'init', '-q')
        run('git', 'add', '-A')
        run('git', 'commit', '-q', '-m', 'Initial commit from cookiecutter-gitops-multirepo template')
        # Name the initial branch after the branch Argo CD tracks (repo_appsets_branch).
        run('git', 'branch', '-M', BRANCH)
        print(f'Initialized a git repository on branch {BRANCH!r} with an initial commit.')
    except (subprocess.CalledProcessError, FileNotFoundError) as exc:
        # Never fail generation just because git init/commit didn't work
        # (git missing, or user.name/user.email not configured).
        print(f'WARNING: init_git step skipped or incomplete: {exc}')
        print('Finish manually with: git init && git add -A && git commit')


if __name__ == '__main__':
    main()
