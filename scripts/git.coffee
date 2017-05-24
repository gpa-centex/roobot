# Git commands
fs = require 'fs'
path = require 'path'
Git = require 'nodegit'
GitHub = require 'github-api'

repoName = 'gpa-centex/gpa-centex.github.io'
repoURL = "https://github.com/#{repoName}.git"
repoPath = path.join __dirname, 'gpa-centex.org'

auth = (url, username) ->
  Git.Cred.userpassPlaintextNew process.env.GITHUB_TOKEN, 'x-oauth-basic'

module.exports =
  pull: (callback) ->
    cloneOpts = fetchOpts: callbacks: credentials: auth
    fs.stat repoPath, (err, stats) ->
      if err
        # Clone
        Git.Clone.clone repoURL, repoPath, cloneOpts
        .then (repository) ->
          callback repository
      else
        # Pull
        repo = {}
        Git.Repository.open repoPath
        .then (repository) ->
          repo = repository
          repo.fetchAll cloneOpts.fetchOpts
        .then ->
          repo.mergeBranches 'master', 'origin/master'
        .done ->
          callback repo

  branch: (repo, name, callback) ->
    ref = {}
    repo.getMasterCommit()
    .then (master) ->
      repo.createBranch name, master, true
    .then (reference) ->
      ref = reference
      repo.checkoutBranch ref, {}
    .done ->
      callback ref

  commit: (repo, user, message, callback) ->
    ndx = {}
    tree = {}
    repo.refreshIndex()
    .then (index) ->
      ndx = index
      ndx.addAll()
    .then ->
      ndx.write()
      ndx.writeTree()
    .then (treeObj) ->
      tree = treeObj
      repo.getHeadCommit()
    .then (parent) ->
      author = Git.Signature.now user.name, user.email
      committer = Git.Signature.now 'roobot', 'website@gpa-centex.org'
      repo.createCommit 'HEAD', author, committer, message, tree, [parent]
    .then (oid) ->
      callback oid

  push: (repo, ref, callback) ->
    repo.getRemote 'origin'
    .then (remote) ->
      pushOpts = callbacks: credentials: auth
      remote.push ["#{ref}:#{ref}"], pushOpts
    .done ->
      callback()

  pullrequest: (title, head, callback) ->
    github = new GitHub {token: process.env.GITHUB_TOKEN}
    repo = github.getRepo repoName
    repo.createPullRequest {title: title, head: head, base: 'master'}
    .then (res) ->
      callback res.data
