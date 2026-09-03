import { existsSync } from 'node:fs'
import { sh } from './github.ts'

/** `<repo>.worktrees/issue-<n>`: every issue gets its own working tree so phases never collide. */
export const worktreePath = (repoPath: string, issue: number): string => `${repoPath}.worktrees/issue-${issue}`

/**
 * Ensures the worktree exists and is on the issue's branch when a PR exists, or detached at
 * origin/main otherwise (the spec/task phases create the branch themselves from the current HEAD).
 */
export const ensureWorktree = async (repoPath: string, issue: number, branch: string | null): Promise<string> => {
  const path = worktreePath(repoPath, issue)
  await sh('git', ['fetch', '--prune', '--quiet', 'origin'], repoPath)
  if (!existsSync(path)) {
    if (branch) {
      await sh('git', ['worktree', 'add', '--quiet', path, '-B', branch, `origin/${branch}`], repoPath)
    } else {
      await sh('git', ['worktree', 'add', '--quiet', '--detach', path, 'origin/main'], repoPath)
    }
  } else if (branch) {
    const current = await sh('git', ['rev-parse', '--abbrev-ref', 'HEAD'], path)
    if (current !== branch) await sh('git', ['checkout', '--quiet', '-B', branch, `origin/${branch}`], path)
    else await sh('git', ['pull', '--quiet', '--ff-only', 'origin', branch], path)
  }
  return path
}

export const removeWorktree = async (repoPath: string, issue: number): Promise<void> => {
  const path = worktreePath(repoPath, issue)
  if (!existsSync(path)) return
  await sh('git', ['worktree', 'remove', '--force', path], repoPath)
}

/** Text appended to every phase prompt so the skill never leaves its worktree. */
export const worktreeNote = (issue: number, branch: string | null): string =>
  `This directory is the dedicated git worktree for issue #${issue}` +
  (branch ? ` on branch ${branch}` : ', detached at origin/main: create the issue branch from the current HEAD with git checkout -b and never run git checkout main') +
  '. Work only here and never switch to another branch or directory.'
