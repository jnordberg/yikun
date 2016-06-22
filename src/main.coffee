### Xiaomi Yi CLI ###

async = require 'async'
fecha = require 'fecha'
fs = require 'fs'
path = require 'path'
printf = require 'printf'
util = require 'util'
yichan = require if process.env['YIKUN_DEV']? then 'yichan/src' else 'yichan'
program = require 'commander'
chalk = require 'chalk'

pkg = require './../package.json'

action = null

defaultCameraAddress = process.env['YI_CAMERA_ADDR'] ? '192.168.42.1'

resolveCameraPath = (cameraPath) ->
  if cameraPath[0] isnt '/' then (path.join '/tmp/fuse_d/', cameraPath) else cameraPath

program
  .version pkg.version
  .option '-v, --verbose', 'enable verbose logging'
  .option '-A --camera-address [address]', "address to camera, default #{ defaultCameraAddress }", defaultCameraAddress

program
  .command 'capture'
  .description 'trigger camera shutter'
  .option '-d, --download', 'whether to download captured photo'
  .option '-o, --output <file>', 'output file if download is set, defaults to stdout'
  .option '-c, --cleanup', 'remove captured file after download'
  .action (options) -> action = -> capturePhoto options, completeHandler

program
  .command 'put <camera_path>'
  .description 'upload a file to the camera'
  .option '-i, --input <file>', 'input file, defaults to stdin'
  .option '-X, --overwrite', 'whether to overwrite existing file, unsafe'
  .action (cameraPath, options) -> action = -> putFile (resolveCameraPath cameraPath), options, completeHandler

program
  .command 'cat <camera_path>'
  .description 'read a file from camera'
  .option '-o, --output <file>', 'output file, defaults to stdout'
  .action (cameraPath, options) -> action = -> readFile (resolveCameraPath cameraPath), options, completeHandler

program
  .command 'rm <camera_path>'
  .description 'remove file from camera'
  .action (cameraPath, options) -> action = -> removeFile (resolveCameraPath cameraPath), options, completeHandler

program
  .command 'ls <camera_path>'
  .description 'list directory on camera'
  .action (cameraPath, options) -> action = -> listDirectory (resolveCameraPath cameraPath), options, completeHandler

program
  .command 'battery'
  .description 'display battery status'
  .action -> action = -> batteryStatus completeHandler

program
  .command 'clock [date]'
  .description 'view or set the camera clock'
  .option '-s, --system', 'set camera clock from system time'
  .action (date, options) -> action = -> clockAction date, options, completeHandler

program
  .command 'cmd <json>'
  .description 'send json command'
  .action (json) -> action = -> sendCommand json, completeHandler

program
  .command 'exec [command]'
  .description 'execute command in ambarella shell'
  .action (command) -> action = ->
    unless command?
      command = ''
      process.stdin.on 'data', (chunk) -> command += chunk
      process.stdin.on 'end', ->
        execCommand command, completeHandler
    else
      execCommand command, completeHandler

program
  .command 'config [name] [value]'
  .description 'read or write camera config'
  .action (name, value) ->
    if name? and value?
      action = -> writeSetting name, value, completeHandler
    else if name?
      action = -> getSetting name, completeHandler
    else
      action = -> showSettings completeHandler

writeSetting = (name, value, callback) ->
  camera.writeSetting name, value, completeHandler

getSetting = (name, callback) ->
  camera.getSetting name, (error, result) ->
    unless error?
      process.stdout.write result.param + '\n'
    callback error

showSettings = (callback) ->
  list = (data, callback) ->
    {current, available} = data
    for key, value of current
      opts = available[key]
      col = if opts.permission is 'settable' then chalk.green else chalk.red
      process.stdout.write "#{ key } = #{ col value }"
      if opts.permission is 'settable'
        process.stdout.write chalk.grey " (#{ opts.options.join ', ' })"
      process.stdout.write '\n'
    callback()
  async.auto
    available: (callback) -> camera.getAvailableSettings callback
    current: (callback) -> camera.getSettings callback
    list: ['available', 'current', list]
  , callback

program
  .command 'reboot'
  .description 'reboot the camera'
  .action -> action = -> rebootCamera completeHandler

noop = ->

log = (msgs...) ->
  out = msgs
    .map (msg) ->
      if typeof msg is 'string'
        return msg
      else
        return util.inspect msg, {colors: true}
    .join ' '
  process.stderr.write out + '\n'

logDebug = log

completeHandler = (error) ->
  if error?
    log "ERROR: #{ error.message }"
    logDebug error
    process.exit 1
  logDebug 'done'
  camera.close()

removeFile = (cameraPath, options, callback) ->
  logDebug 'removing', cameraPath
  camera.deleteFile cameraPath, callback

listDirectory = (cameraPath, options, callback) ->
  logDebug 'listing', cameraPath
  camera.listDirectory cameraPath, (error, result) ->
    unless error?
      for file in result
        process.stdout.write printf '% 10d  %s  %s\n', file.size, (fecha.format file.date, 'YYYY-MM-DD HH:mm:ss'), file.name
    callback error

putFile = (cameraPath, options, callback) ->
  logDebug 'uploading to', cameraPath
  if options.input?
    logDebug 'using', options.input
    input = fs.createReadStream options.input
  else
    logDebug 'using stdin'
    input = process.stdin

  basename = path.basename cameraPath

  checkExisting = (callback) ->
    camera.listDirectory (path.dirname cameraPath), (error, result) ->
      unless error?
        rv = (result.find (item) -> item.name is basename)
      callback error, rv

  removeExisting = (shared, callback) ->
    if shared.check?
      logDebug 'file exists', shared.check
      if options.overwrite isnt true
        error = new Error 'File exists, use -X to write anyway.'
    callback error

  uploadFile = (shared, callback) ->
    logDebug 'uploading...'
    dst = camera.createWriteStream cameraPath
    dst.on 'error', callback
    dst.on 'finish', callback
    input.pipe dst

  async.auto
    check: checkExisting
    remove: ['check', removeExisting]
    upload: ['remove', uploadFile]
  , callback

readFile = (cameraPath, options, callback) ->
  logDebug 'downloading', cameraPath
  if options.output?
    logDebug 'writing to', options.output
    output = fs.createWriteStream options.output
  else
    logDebug 'writing to stdout'
    output = process.stdout
  src = camera.createReadStream cameraPath
  src.on 'error', callback
  src.on 'end', callback
  src.pipe output

rebootCamera = (callback) ->
  camera.sendCmd {msg_id: 2, type: 'dev_reboot', param: 'on'}, -> do callback

sendCommand = (json, callback) ->
  try
    cmd = JSON.parse json
  catch error
    error.message = "Unable to parse '#{ json }' (#{ error.message })"
    callback error
    return
  logDebug 'sending', cmd
  camera.sendCmd cmd, (error, result) ->
    unless error?
      log result
    callback error

batteryStatus = (callback) ->
  camera.sendCmd {msg_id: 13}, (error, result) ->
    unless error?
      process.stdout.write "source #{ result.type }\n level #{ result.param }%\n"
    callback error

clockAction = (date, options, callback) ->
  clockFmt = 'YYYY-MM-DD HH:mm:ss'
  if date?
    parsed = fecha.parse date, clockFmt
    if parsed is false
      callback new Error "Invalid date: '#{ date }', format should be #{ clockFmt }"
      return
    date = parsed
  else if options.system
    date = new Date

  if date?
    cameraDate = fecha.format date, clockFmt
    logDebug 'setting clock to', cameraDate
    camera.sendCmd {msg_id: 2, type: 'camera_clock', param: cameraDate}, callback
  else
    camera.sendCmd {msg_id: 9, param: 'camera_clock'}, (error, result) ->
      unless error?
        log result.options[0]
      callback error

capturePhoto = (options, callback) ->
  logDebug 'triggering shutter'
  camera.triggerShutter (error) ->
    unless error?
      if options.download or options.cleanup
        return
    callback error
  if options.download or options.cleanup
    camera.on 'photo_taken', (filename) ->
      logDebug 'photo taken', filename
      tasks = []
      if options.download
        if options.output?
          logDebug 'writing to', options.output
          output = fs.createWriteStream options.output
        else
          logDebug 'writing to stdout'
          output = process.stdout
        tasks.push (callback) ->
          logDebug 'downloading', filename
          photo = camera.createReadStream filename
          photo.on 'error', callback
          photo.on 'end', callback
          photo.pipe output
      if options.cleanup
        tasks.push (callback) ->
          logDebug 'removing', filename
          camera.deleteFile filename, callback
      async.series tasks, callback

execCommand = (command, callback) ->
  camera.execCommand command, (error, result) ->
    unless error?
      process.stdout.write result
    callback error

program.parse process.argv

unless program.verbose is true
  logDebug = noop

unless action?
  program.outputHelp()
  process.exit()

logDebug 'connecting to', program.cameraAddress

camera = new yichan
  cameraHost: program.cameraAddress
  cmdTimeout: 10 * 1000

camera.on 'connected', ->
  logDebug 'connected to camera'

camera.on 'event', (event) ->
  logDebug 'camera event', event

camera.on 'error', (error) ->
  log "CAMERA ERROR: #{ error.message }"
  logDebug error

do action
