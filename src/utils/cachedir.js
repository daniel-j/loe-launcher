'use strict'

const os = require('os')
const path = require('path')

function linux (id) {
  const cacheHome = process.env.XDG_CACHE_HOME || path.join(os.homedir(), '.cache')
  return path.join(cacheHome, id)
}

function darwin (id) {
  return path.join(os.homedir(), 'Library', 'Caches', id)
}

function win32 (id) {
  const appData = process.env.LOCALAPPDATA || path.join(os.homedir(), 'AppData', 'Local')
  return path.join(appData, id, 'Cache')
}

const implementation = (function () {
  switch (os.platform()) {
    case 'android':
    case 'linux': return linux
    case 'darwin': return darwin
    case 'win32': return win32
    default: throw new Error('cachedir: Your OS ' + os.platform() + ' is currently not supported.')
  }
}())

module.exports = function (id) {
  if (typeof id !== 'string') {
    throw new TypeError('id is not a string')
  }
  if (id.length === 0) {
    throw new Error('id cannot be empty')
  }
  if (/[^0-9a-zA-Z- ]/.test(id)) {
    throw new Error('id cannot contain special characters')
  }

  return implementation(id)
}
