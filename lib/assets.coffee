async = require 'async'
uuid = require 'node-uuid'
Asset = require('./asset').Asset
EventEmitter = require('events').EventEmitter

class exports.Assets extends EventEmitter
  constructor: ->
    for arg in arguments
      if Array.isArray arg
        @assets = arg
        continue
      switch typeof arg
        when 'function' then callback = arg
        when 'object' then @options = arg

    for asset in @assets
      for k, v of @options
        asset.config[k] ?= v
      
    @dsts = {}
    @urls = {}
    if callback
      process.nextTick =>
        @on 'complete', =>
          callback null
        @on 'error', (err) =>
          callback err
        @wrap()

  wrap: ->
    async.forEach @assets, (asset, next) =>
      asset.on 'complete', =>
        @dsts[asset.dst] = asset
        @urls[asset.url] = asset
        next()
      asset.on 'error', (err) =>
        if @options.ignoreErrors
          next()
        else
          @emit 'error', err
      asset.wrap()
    , (err) =>
      return @emit 'error', err if err?
      @emit 'complete'

  # add a middleware hook to serve assets from
  middleware: (req, res, next) =>
    asset = @urls[req.url]
    return next() unless asset?
    res.set 'Cache-Control', asset.cache
    res.set 'Content-Type', asset.type
    res.send asset.data

  # push assets to a cdn
  push: (host, config, next) ->
    switch host
      when 's3'
        console.log 's3'
        next()
      when 'cloudfiles'
        console.log 'cloudfiles'
        next()

  # merge all asset data. should only be used if all assets have same mimetype
  # returns a single asset
  merge: (config={}) ->
    config.src = config.src or uuid.v4()
    data = []
    type = null
    for dst, asset of @dsts
      data.push asset.data
      type ?= asset.type
      if type is not asset.type
        throw new Error 'mimetypes must match for all assets to merge'
    asset = new Asset config
    asset.type = type
    switch type
      when 'text/javascript' then asset.data = data.join ';'
      else asset.data = data.join ''
    asset.emit 'complete'
    return asset

  # Shortcuts
  data: (dst) ->  @dsts[dst].data
  get: (dst) ->   @dsts[dst]
  md5: (dst) ->   @dsts[dst].md5
  src: (dst) ->   @dsts[dst].src
  tag: (dst) ->   @dsts[dst].tag
  url: (dst) ->   @dsts[dst].url

