
console.time('init')

const crashReporter = require('../crash-reporter')
crashReporter.init()

const State = require('../state')
// State.load(onState)

const electron = require('electron')

const ipcRenderer = electron.ipcRenderer

function setupIpc () {
  ipcRenderer.on('log', (e, ...args) => console.log(...args))
  ipcRenderer.on('error', (e, ...args) => console.error(...args))

  ipcRenderer.send('ipcReady')
}

setupIpc()

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
