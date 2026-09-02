---
name: pr-review
description: Review and resolve GitHub PR comments following the project's review workflow
---

## When to use

Use this skill when the user asks to:

- Review PR comments
- Address PR review feedback
- Check for unresolved review threads

## Workflow

### 1. Fetch review comments

```bash
gh api repos/{owner}/{repo}/pulls/{number}/comments \
  --jq '.[] | select(.user.login == "Copilot") | {id: .id, path: .path, line: .line, body: .body}'
```

Also check for non-bot comments:

```bash
gh api repos/{owner}/{repo}/pulls/{number}/comments \
  --jq '.[] | select(.user.login != "Copilot") | {id: .id, path: .path, line: .line, body: .body, user: .user.login}'
```

### 2. Process each comment

For each comment, present it to the user and **ask which action to take** before doing anything. Offer these options:

- **Fix it** — implement the suggested change
- **Reject it** — reply explaining why the suggestion is not applicable
- **Skip** — move to the next comment without acting

**NEVER implement a fix or reply to a comment without the user's explicit decision.**

Once the user decides:

1. Read the referenced file and understand the context
2. If "Fix it": implement the change
3. If "Reject it": draft a reply explaining why, show it to the user for approval, then post it
4. If "Skip": move to the next comment

After fixing or rejecting, reply to the comment and resolve the thread (steps 3-4 below).

### 3. Reply to the comment

Reply using the PR comment reply API:

```bash
gh api repos/{owner}/{repo}/pulls/{number}/comments/{comment_id}/replies \
  -f body="<explanation of what was done>"
```

### 4. Resolve the review thread

**MANDATORY**: After replying to every comment, resolve its review thread.

First, get the thread IDs:

```bash
gh api graphql -f query='
{
  repository(owner: "{owner}", name: "{repo}") {
    pullRequest(number: {number}) {
      reviewThreads(first: 50) {
        nodes {
          id
          isResolved
          comments(first: 1) {
            nodes { databaseId body }
          }
        }
      }
    }
  }
}'
```

Then resolve each thread that was addressed:

```bash
gh api graphql -f query='
mutation {
  resolveReviewThread(input: {threadId: "{thread_node_id}"}) {
    thread { isResolved }
  }
}'
```

**IMPORTANT**: Do NOT use `minimizeComment` — that hides the comment instead of resolving it.

### 5. Verify all threads resolved

After processing all comments, verify no unresolved threads remain:

```bash
gh api graphql -f query='
{
  repository(owner: "{owner}", name: "{repo}") {
    pullRequest(number: {number}) {
      reviewThreads(first: 50) {
        nodes {
          id
          isResolved
          comments(first: 1) {
            nodes { body }
          }
        }
      }
    }
  }
}' --jq '.data.repository.pullRequest.reviewThreads.nodes[] | select(.isResolved == false)'
```

## Commit convention

Each fix should be a separate commit. Use **Conventional Commits with a package scope** (the part after the workspace prefix, e.g. `order-management`, `api-server`), matching `@committer`'s convention:

```
<type>(<scope>): <short description of what the review comment asked for>
```

Example: `fix(api-server): scope repository instantiation per request`.

Prefer delegating the staging + commit to **`@committer`**, which groups changes into atomic commits and enforces this format. Run tests before committing to ensure nothing is broken.

## Key rules

- **Always ask the user** what to do with each comment before acting — never auto-fix or auto-reject
- Always reply to the comment BEFORE resolving the thread
- Always resolve the thread AFTER replying — never leave threads unresolved
- Never use `minimizeComment` — it hides comments, it does not resolve them
- Group related fixes into a single commit when they address the same concern
- Push after all comments are addressed, not after each individual fix
