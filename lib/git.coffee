# Git commands

fs = require 'fs'
fse = require 'fs-extra'
path = require 'path'
Git = require 'nodegit'
GitHub = require 'github-api'

repoName = 'galtx-centex/galtx-centex.github.io'
repoURL = "https://github.com/#{repoName}.git"
repoPath = path.join __dirname, 'galtx-centex.org'

auth = (url, username) ->
  Git.Cred.userpassPlaintextNew process.env.GITHUB_TOKEN, 'x-oauth-basic'

clone = (clonePath) ->
  new Promise (resolve, reject) ->
    console.log "clone #{repoURL} to #{clonePath}"
    cloneOpts = fetchOpts: callbacks: credentials: auth
    Git.Clone.clone repoURL, clonePath, cloneOpts
    .then (repo) ->
      resolve repo
    .catch (err) ->
      reject "Clone #{err}"

checkout = (repo, branch) ->
  new Promise (resolve, reject) ->
    ref = null
    repo.getReference branch
    .then (reference) ->
      ref = reference
      console.log "ref checkout #{ref}"
      repo.checkoutRef ref
    .then () ->
      resolve ref
    .catch (err) ->
      reject "Checkout #{err}"

commit = (repo, user, message) ->
  new Promise (resolve, reject) ->
    ndx = null
    tree = null
    repo.refreshIndex()
    .then (index) ->
      ndx = index
      ndx.addAll()
    .then () ->
      ndx.write()
      ndx.writeTree()
    .then (treeObj) ->
      tree = treeObj
      repo.getHeadCommit()
    .then (parent) ->
      console.log "commit '#{message}' from <#{user.name} #{user.email}>"
      author = Git.Signature.now user.name, user.email
      committer = Git.Signature.now 'RooBot', 'roobot@galtx-centex.org'
      repo.createCommit 'HEAD', author, committer, message, tree, [parent]
    .then (oid) ->
      resolve oid
    .catch (err) ->
      reject "Commit #{err}"

tag = (repo, oid) ->
  new Promise (resolve, reject) ->
    console.log "tag #{oid}"
    repo.createLightweightTag oid, "#{oid}-tag"
    .then (reference) ->
      resolve reference
    .catch (err) ->
      reject "Tag #{err}"

push = (repo, src, dst) ->
  new Promise (resolve, reject) ->
    refSpec = "#{src}:#{dst}"
    repo.getRemote 'origin'
    .then (remote) ->
      console.log "push origin #{refSpec}"
      pushOpts = callbacks: credentials: auth
      remote.push ["#{refSpec}"], pushOpts
    .then () ->
      resolve()
    .catch (err) ->
      reject "Push #{err}"

newPullRequest = (title, head) ->
  new Promise (resolve, reject) ->
    console.log "open PR #{title}"
    github = new GitHub {token: process.env.GITHUB_TOKEN}
    repo = github.getRepo repoName
    repo.createPullRequest {title: title, head: head, base: 'main'}
    .then ({data}) ->
      resolve data
    .catch (err) ->
      reject "New PR #{err}"

findPullRequest = (head) ->
  new Promise (resolve, reject) ->
    console.log "find PR #{head}"
    github = new GitHub {token: process.env.GITHUB_TOKEN}
    repo = github.getRepo repoName
    repo.listPullRequests {state: 'open', head: "galtx-centex:#{head}"}
    .then ({data}) ->
      resolve data[0] ? null
    .catch (err) ->
      reject "Find PR #{err}"

module.exports =
  review: (action, args..., opts, callback) ->
    clonePath = "#{repoPath}-#{opts.branch}-#{Date.now()}"
    clone clonePath
    .then (repo) ->
      opts.repo = repo
      findPullRequest opts.branch
    .then (pr) ->
      opts.pr = pr
      opts.head =
        if pr?.head?
          "origin/#{pr.head.ref}"
        else
          'origin/main'
      checkout opts.repo, opts.head
    .then (ref) ->
      new Promise (resolve, reject) ->
        action clonePath, args..., (err) ->
          unless err?
            resolve()
          else
            reject err
    .then () ->
      commit opts.repo, opts.user, opts.message
    .then (oid) ->
      tag opts.repo, oid
    .then (tag) ->
      push opts.repo, tag, "refs/heads/#{opts.branch}"
    .then () ->
      if opts.pr?
        new Promise (resolve, reject) -> resolve(opts.pr)
      else
        newPullRequest opts.message, opts.branch
    .then (pr) ->
      callback "Pull Request ready ➜ #{pr.html_url}"
    .catch (err) ->
      callback err
    .finally ->
      console.log "Remove #{clonePath}"
      fse.remove clonePath
      console.log "Done"

  update: (action, args..., opts, callback) ->
    clonePath = "#{repoPath}-#{opts.branch}-#{Date.now()}"
    clone clonePath
    .then (repo) ->
      opts.repo = repo
      checkout opts.repo, 'main'
    .then (ref) ->
      opts.ref = ref
      new Promise (resolve, reject) ->
        action clonePath, args..., (err) ->
          unless err?
            resolve()
          else
            reject err
    .then () ->
      commit opts.repo, opts.user, opts.message
    .then (oid) ->
      push opts.repo, opts.ref, opts.ref
    .then () ->
      callback null
    .catch (err) ->
      callback err
    .finally ->
      console.log "Remove #{clonePath}"
      fse.remove clonePath
      console.log "Done"
