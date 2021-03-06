# Utility functions
fs = require 'fs'
url = require 'url'
https = require 'https'
slugify = require 'slugify'
capitalize = require 'capitalize'

module.exports =
  nowDate: () ->
    now = new Date()
    new Date Date.UTC(now.getFullYear(), now.getMonth(), now.getDate())

  thisDate: (dateString) ->
    # mm/dd/yyyy
    dateRegex = /(\d{1,2})\/(\d{1,2})\/(\d{4})/
    match = dateRegex.exec(dateString)
    month = parseInt(match[1], 10)
    day = parseInt(match[2], 10)
    year = parseInt(match[3], 10)
    new Date(year, month - 1, day)

  download: (src, dest, callback) ->
    console.log "Download #{src}"
    file = fs.createWriteStream dest
    opts = url.parse src
    opts.headers =
      Authorization: "Bearer #{process.env.HUBOT_SLACK_TOKEN}"
    https.get opts, (resp) ->
      resp.pipe file
      file.on 'finish', ->
        console.log "Download finished"
        # close() is async, call callback after close completes.
        file.close callback
    # Handle errors
    .on 'error', (err) ->
      # Delete the file async. (But we don't check the result)
      fs.unlink dest
      callback err.message

  slugify: (name) ->
    return slugify name, {lower: true}

  capitalize: (name) ->
    return capitalize.words name
