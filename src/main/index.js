console.time('init')

const electron = require('electron')
const {app, BrowserWindow} = electron
const config = require('../config')
const crashReporter = require('../crash-reporter')
const ipc = require('./ipc')
const log = require('./log')
const State = require('./state')
const windows = require('./windows')

const path = require('path')

let shouldQuit = false
let argv = sliceArgv(process.argv)

// Start the app without showing the main window when auto launching on login
// (On Windows and Linux, we get a flag. On MacOS, we get special API.)
const hidden = argv.includes('--hidden') || (process.platform === 'darwin' && app.getLoginItemSettings().wasOpenedAsHidden)

if (config.IS_PRODUCTION) {
  // When Electron is running in production mode (packaged app), set NODE_ENV
  process.env.NODE_ENV = 'production'
}

if (!shouldQuit) {
  // Prevent multiple instances of app from running at same time. New instances
  // signal this instance and quit. Note: This feature creates a lock file in
  // %APPDATA%\Roaming\WebTorrent so we do not do it for the Portable App since
  // we want to be "silent" as well as "portable".
  shouldQuit = app.makeSingleInstance(onAppOpen)
  if (shouldQuit) {
    app.quit()
  }
}

if (!shouldQuit) {
  init()
}

function init () {
  const ipcMain = electron.ipcMain

  let isReady = false // app ready, windows can be created
  app.ipcReady = false // main window has finished loading and IPC is ready
  app.isQuitting = false

  app.on('ready', () => State.load(onReady))

  function onReady (err, results) {

    isReady = true
    const state = results.state

    windows.main.init(state, {hidden: hidden})
    windows.webtorrent.init()

    // To keep app startup fast, some code is delayed.
    setTimeout(() => {
      delayedInit(state)
    }, config.DELAYED_INIT)

    // Report uncaught exceptions
    process.on('uncaughtException', (err) => {
      console.error(err)
      const error = {message: err.message, stack: err.stack}
      windows.main.dispatch('uncaughtError', 'main', error)
    })
  }

  app.on('open-file', onOpen)
  app.on('open-url', onOpen)

  ipc.init()

  app.once('will-finish-launching', function () {
    crashReporter.init()
  })

  app.once('ipcReady', function () {
    log('Command line args:', argv)
    processArgv(argv)
    console.timeEnd('init')
  })

  app.on('before-quit', function (e) {
    if (app.isQuitting) return

    app.isQuitting = true
    e.preventDefault()
    windows.main.dispatch('stateSaveImmediate') // try to save state on exit
    ipcMain.once('stateSaved', () => app.quit())
    setTimeout(() => {
      console.error('Saving state took too long. Quitting.')
      app.quit()
    }, 4000) // quit after 4 secs, at most
  })

  app.on('activate', function () {
    if (isReady) windows.main.show()
  })
}

function delayedInit (state) {
  if (app.isQuitting) return

  const announcement = require('./announcement')
  const dock = require('./dock')
  const updater = require('./updater')

  announcement.init()
  dock.init()
  updater.init()

  if (process.platform === 'win32') {
    const userTasks = require('./user-tasks')
    userTasks.init()
  }

  if (process.platform !== 'darwin') {
    const tray = require('./tray')
    tray.init()
  }
}

function onOpen (e, appArgs) {
  e.preventDefault()

  if (app.ipcReady) {
    // Electron issue: https://github.com/atom/electron/issues/4338
    setTimeout(() => windows.main.show(), 100)

    processArgv(appArgs)
  } else {
    argv.push(...appArgs)
  }
}

function onAppOpen (newArgv) {
  newArgv = sliceArgv(newArgv)

  if (app.ipcReady) {
    log('Second app instance opened, but was prevented:', newArgv)
    windows.main.show()

    processArgv(newArgv)
  } else {
    argv.push(...newArgv)
  }
}

// Remove leading args.
// Production: 1 arg, eg: /Applications/Legends of Equestria.app/Contents/MacOS/loe-launcher
// Development: 2 args, eg: electron .
function sliceArgv (argv) {
  return argv.slice(config.IS_PRODUCTION ? 1 : 2)
}

function processArgv (argv) {
  let appArgs = []
  argv.forEach(function (arg) {
    if (arg === '-n' || arg === '-o' || arg === '-u') {
      // Critical path: Only load the 'dialog' package if it is needed
      const dialog = require('./dialog')
      if (arg === '-n') {
        dialog.openSeedDirectory()
      } else if (arg === '-o') {
        dialog.openTorrentFile()
      } else if (arg === '-u') {
        dialog.openTorrentAddress()
      }
    } else if (arg === '--hidden') {
      // Ignore hidden argument, already being handled
    } else if (arg.startsWith('-psn')) {
      // Ignore Mac launchd "process serial number" argument
      // Issue: https://github.com/webtorrent/webtorrent-desktop/issues/214
    } else if (arg.startsWith('--')) {
      // Ignore Spectron flags
    } else if (arg === 'data:,') {
      // Ignore weird Spectron argument
    } else if (arg !== '.') {
      // Ignore '.' argument, which gets misinterpreted as an argument, when a
      // development copy is started while a production version is running.
      appArgs.push(arg)
    }
  })
  if (appArgs.length > 0) {
    windows.main.dispatch('onOpen', appArgs)
  }
}

/*

// Keep a global reference of the window object, if you don't, the window will
// be closed automatically when the JavaScript object is garbage collected.
let mainWindow

function onReady () {
  const ipcMain = electron.ipcMain
  createWindow()
}

function createWindow () {
  // Create the browser window.
  mainWindow = new BrowserWindow({
    minWidth: 600,
    minHeight: 350,
    width: 640,
    height: 360,
    useContentSize: true,
    fullscreenable: false,
    show: false,
    title: 'Legends of Equestria Launcher',
    autoHideMenuBar: true,
    darkTheme: true,
    titleBarStyle: 'hiddenInset',
    webPreferences: {
      webgl: false,
      webaudio: false
    }
  })

  // and load the index.html of the app.
  mainWindow.loadFile(path.join(__dirname, '..', '..', 'static', 'app.html'))

  mainWindow.on('ready-to-show', () => {
    mainWindow.show()
  })

  // Open the DevTools.
  // mainWindow.webContents.openDevTools()

  // Emitted when the window is closed.
  mainWindow.on('closed', () => {
    // Dereference the window object, usually you would store windows
    // in an array if your app supports multi windows, this is the time
    // when you should delete the corresponding element.
    mainWindow = null
  })
}

// This method will be called when Electron has finished
// initialization and is ready to create browser windows.
// Some APIs can only be used after this event occurs.
app.on('ready', onReady)

// Quit when all windows are closed.
app.on('window-all-closed', () => {
  // On OS X it is common for applications and their menu bar
  // to stay active until the user quits explicitly with Cmd + Q
  if (process.platform !== 'darwin') {
    app.quit()
  }
})

app.on('activate', () => {
  // On OS X it's common to re-create a window in the app when the
  // dock icon is clicked and there are no other windows open.
  if (mainWindow === null) {
    createWindow()
  }
})

// In this file you can include the rest of your app's specific main process
// code. You can also put them in separate files and require them here.
*/
