
console.time('init')

const crashReporter = require('../crash-reporter')
crashReporter.init()

// Perf optimization: Start asynchronously read on config file before all the
// blocking require() calls below.

const State = require('../state')
State.load(onState)

const electron = require('electron')
const fs = require('fs')
const config = require('../config')

const ipcRenderer = electron.ipcRenderer

// Yo-yo pattern: state object lives here and percolates down thru all the views.
// Events come back up from the views via dispatch(...)
require('./lib/dispatcher').setDispatch(dispatch)

// All state lives in state.js. `state.saved` is read from and written to a file.
// All other state is ephemeral. First we load state.saved then initialize the app.
let state

// Called once when the application loads. (Not once per window.)
// Connects to the torrent networks, sets up the UI and OS integrations like
// the dock icon and drag+drop.
function onState (err, _state) {
  if (err) return onError(err)

  // Make available for easier debugging
  state = window.state = _state
  window.dispatch = dispatch

  // Log uncaught JS errors
  /*
  window.addEventListener(
    'error', (e) => telemetry.logUncaughtError('window', e), true // capture
  )
  */

  setInterval(update, 1000)

  setupIpc()

  // To keep app startup fast, some code is delayed.
  window.setTimeout(delayedInit, config.DELAYED_INIT)

  // Done! Ideally we want to get here < 500ms after the user clicks the app
  console.timeEnd('init')
}

// Runs a few seconds after the app loads, to avoid slowing down startup time
function delayedInit () {
  // Warn if the download dir is gone, eg b/c an external drive is unplugged
  checkDownloadPath()
}

function update () {
  // controllers.playback().showOrHidePlayerControls()
  // app.setState(state)
  // m.redraw()

  // Some state changes can't be reflected in the DOM, instead we have to
  // tell the main process to update the window or OS integrations
  if (state.window.title !== state.prev.title) {
    state.prev.title = state.window.title
    ipcRenderer.send('setTitle', state.window.title)
  }
  if (state.dock.progress.toFixed(2) !== state.prev.progress.toFixed(2)) {
    state.prev.progress = state.dock.progress
    ipcRenderer.send('setProgress', state.dock.progress)
  }
  if (state.dock.badge !== state.prev.badge) {
    state.prev.badge = state.dock.badge
    ipcRenderer.send('setBadge', state.dock.badge || 0)
  }
}

const dispatchHandlers = {
  error: onError,
  stateSave: () => State.save(state),
  stateSaveImmediate: () => State.saveImmediate(state),
  update: () => {} // No-op, just trigger an update
}

// Events from the UI never modify state directly. Instead they call dispatch()
function dispatch (action, ...args) {
  // Log dispatch calls, for debugging, but don't spam
  if (!['mediaMouseMoved', 'mediaTimeUpdate', 'update'].includes(action)) {
    console.log('dispatch: %s %o', action, args)
  }

  const handler = dispatchHandlers[action]
  if (handler) handler(...args)
  else console.error('Missing dispatch handler: ' + action)

  // Update the virtual DOM, unless it's just a mouse move event
  if (action !== 'mediaMouseMoved') {
    update()
  }
}

function setupIpc () {
  ipcRenderer.on('log', (e, ...args) => console.log(...args))
  ipcRenderer.on('error', (e, ...args) => console.error(...args))

  ipcRenderer.on('dispatch', (e, ...args) => dispatch(...args))

  ipcRenderer.send('ipcReady')

  State.on('stateSaved', () => ipcRenderer.send('stateSaved'))
}

function onError (err) {
  console.error(err.stack || err)
  state.errors.push({
    time: new Date().getTime(),
    message: err.message || err
  })

  update()
}

function checkDownloadPath () {
  fs.stat(state.saved.prefs.downloadPath, function (err, stat) {
    if (err) {
      state.downloadPathStatus = 'missing'
      return console.error(err)
    }
    if (stat.isDirectory()) state.downloadPathStatus = 'ok'
    else state.downloadPathStatus = 'missing'
  })
}

window.addEventListener('load', () => {
  const newsview = document.getElementById('newsview')
  document.body.className = 'loading'
  setTimeout(() => {
    document.body.className += ' loaded'
    // newsview.openDevTools()
  }, 1000)

  newsview.addEventListener('new-window', (e) => {
    const protocol = require('url').parse(e.url).protocol
    if (protocol === 'http:' || protocol === 'https:' || protocol === 'mailto:') {
      electron.shell.openExternal(e.url)
    } else {
      console.log('unknown url ' + e.url)
    }
  })
}, false)
