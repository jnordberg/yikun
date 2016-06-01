### Xiaomi Yi CLI ###

async = require 'async'
fecha = require 'fecha'
fs = require 'fs'
path = require 'path'
printf = require 'printf'
util = require 'util'
yichan = require 'yichan'

program = require 'commander'

pkg = require './../package.json'

action = null

defaultCameraAddress = process.env['YI_CAMERA_ADDR'] ? '192.168.42.1'

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
  .action (cameraPath, options) -> action = -> putFile cameraPath, options, completeHandler

program
  .command 'cat <camera_path>'
  .description 'read a file from camera'
  .option '-o, --output <file>', 'output file, defaults to stdout'
  .action (cameraPath, options) -> action = -> readFile cameraPath, options, completeHandler

program
  .command 'rm <camera_path>'
  .description 'remove file from camera'
  .action (cameraPath, options) -> action = -> removeFile cameraPath, options, completeHandler

program
  .command 'ls <camera_path>'
  .description 'list directory on camera'
  .action (cameraPath, options) -> action = -> listDirectory cameraPath, options, completeHandler

program
  .command 'battery'
  .description 'display battery status'
  .action -> action = -> batteryStatus completeHandler

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

batteryStatus = (callback) ->
  camera.sendCmd {msg_id: 13}, (error, result) ->
    unless error?
      process.stdout.write "source #{ result.type }\n level #{ result.param }%\n"
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
