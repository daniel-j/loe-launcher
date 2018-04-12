const main = module.exports = {
  dispatch,
  hide,
  init,
  send,
  setProgress,
  setTitle,
  show,
  toggleDevTools,
  win: null
}

const electron = require('electron')

const app = electron.app

const config = require('../../config')
const log = require('../log')

function init (state, options) {
  if (main.win) {
    return main.win.show()
  }

  const initialBounds = Object.assign(config.WINDOW_INITIAL_BOUNDS)

  const win = main.win = new electron.BrowserWindow({
    backgroundColor: '#FFFFFF',
    backgroundThrottling: true, // do not throttle animations/timers when page is background
    darkTheme: true, // Forces dark theme (GTK+3)
    height: initialBounds.height,
    icon: getIconPath(), // Window icon (Windows, Linux)
    minHeight: config.WINDOW_MIN_HEIGHT,
    minWidth: config.WINDOW_MIN_WIDTH,
    show: false,
    title: config.APP_WINDOW_TITLE,
    titleBarStyle: 'hidden-inset', // Hide title bar (Mac)
    useContentSize: true, // Specify web page size without OS chrome
    width: initialBounds.width,
    x: initialBounds.x,
    y: initialBounds.y
  })

  win.loadFile(config.WINDOW_MAIN)

  // No menu
  win.setMenu(null)

  win.once('ready-to-show', () => {
    if (!options.hidden) win.show()
  })

  if (win.setSheetOffset) {
    // win.setSheetOffset(config.UI_HEADER_HEIGHT)
  }

  win.webContents.on('will-navigate', (e, url) => {
    // Prevent drag-and-drop from navigating the Electron window, which can happen
    // before our drag-and-drop handlers have been initialized.
    e.preventDefault()
  })

  win.on('close', function (e) {
    if (process.platform !== 'darwin') {
      app.quit()
      return
    }
    if (!app.isQuitting) {
      e.preventDefault()
      hide()
    }
  })
}

function dispatch (...args) {
  send('dispatch', ...args)
}

function hide () {
  if (!main.win) return
  dispatch('backToList')
  main.win.hide()
}

function send (...args) {
  if (!main.win) return
  main.win.send(...args)
}


/**
 * Set progress bar to [0, 1]. Indeterminate when > 1. Remove with < 0.
 */
function setProgress (progress) {
  if (!main.win) return
  main.win.setProgressBar(progress)
}

function setTitle (title) {
  if (!main.win) return
  main.win.setTitle(title)
}

function show () {
  if (!main.win) return
  main.win.show()
}

function toggleDevTools () {
  if (!main.win) return
  log('toggleDevTools')
  if (main.win.webContents.isDevToolsOpened()) {
    main.win.webContents.closeDevTools()
  } else {
    main.win.webContents.openDevTools({ detach: true })
  }
}

function getIconPath () {
  return process.platform === 'win32'
    ? config.APP_ICON + '.ico'
    : config.APP_ICON + '.png'
}
