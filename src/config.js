const APP_NAME = 'Legends of Equestria Launcher'
const APP_TEAM = 'Legends of Equestria Team'
const APP_VERSION = require('../package.json').version

const appConfig = require('application-config')(APP_NAME)
const path = require('path')
const electron = require('electron')
const arch = require('arch')

const IS_PRODUCTION = isProduction()

module.exports = {
  ANNOUNCEMENT_URL: '',
  AUTO_UPDATE_URL: '',
  CRASH_REPORT_URL: '',

  APP_COPYRIGHT: 'Copyright © 2011-2018 ' + APP_TEAM,
  APP_ICON: path.join(__dirname, '..', 'static', 'assets', 'icon'),
  APP_NAME: APP_NAME,
  APP_TEAM: APP_TEAM,
  APP_VERSION: APP_VERSION,
  APP_WINDOW_TITLE: APP_NAME,

  CONFIG_PATH: getConfigPath(),

  DELAYED_INIT: 0,

  DEFAULT_DOWNLOAD_PATH: getDefaultDownloadPath(),

  GITHUB_URL: 'https://github.com/daniel-j/loe-launcher',
  GITHUB_URL_ISSUES: 'https://github.com/daniel-j/loe-launcher/issues',

  HOME_PAGE_URL: 'https://www.legendsofequestria.com',

  IS_PRODUCTION: IS_PRODUCTION,

  OS_SYSARCH: arch() === 'x64' ? 'x64' : 'ia32',

  GAME_PATH: path.join(getConfigPath(), 'game'),
  ROOT_PATH: path.join(__dirname, '..'),
  STATIC_PATH: path.join(__dirname, '..', 'static'),

  WINDOW_ABOUT: path.join(__dirname, '..', 'static', 'about.html'),
  WINDOW_MAIN: path.join(__dirname, '..', 'static', 'app.html'),
  WINDOW_WEBTORRENT: path.join(__dirname, '..', 'static', 'webtorrent.html'),

  WINDOW_INITIAL_BOUNDS: {
    width: 640,
    height: 360
  },
  WINDOW_MIN_HEIGHT: 600,
  WINDOW_MIN_WIDTH: 350
}

function getConfigPath () {
  return path.dirname(appConfig.filePath)
}

function getDefaultDownloadPath () {
  return getPath('downloads') // TODO
}

function getPath (key) {
  if (!process.versions.electron) {
    // Node.js process
    return ''
  } else if (process.type === 'renderer') {
    // Electron renderer process
    return electron.remote.app.getPath(key)
  } else {
    // Electron main process
    return electron.app.getPath(key)
  }
}

function isProduction () {
  if (!process.versions.electron) {
    // Node.js process
    return false
  }
  if (process.platform === 'darwin') {
    return !/\/Electron\.app\//.test(process.execPath)
  }
  if (process.platform === 'win32') {
    return !/\\electron\.exe$/.test(process.execPath)
  }
  if (process.platform === 'linux') {
    return !/\/electron$/.test(process.execPath)
  }
}
