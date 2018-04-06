// const {app, BrowserWindow} = require('electron')

const fs = require('fs')
const path = require('path')
const zlib = require('zlib')
const mkdirp = require('mkdirp')
const progress = require('progress-stream')
const promiseLimit = require('promise-limit')
const fetch = require('./src/fetch')
const utils = require('./src/utils')

const WebTorrent = require('webtorrent')

const client = new WebTorrent()

client.on('torrent', (torrent) => {
  console.log('torrent ready')
})

fetch('https://djazz.se/nas/games/loe/loe-linux.torrent', {}, (err, data) => {
  const torrent = client.add(data, {path: 'torrent'}, (torrent) => {
    console.log('torrent ready')
    // console.log(torrent)
    torrent.on('warning', (warn) => {
      console.warn('webtorrent warn: ' + warn)
    })
    torrent.on('download', (bytes) => {
      console.log(Math.round(torrent.timeRemaining / 1000 / 60) + ' min', Math.round(torrent.progress * 100) + '%', Math.round(torrent.downloaded / 1024 / 1024), torrent.downloadSpeed / 1024 / 1024)
    })
    torrent.on('upload', () => {
      console.log('upload', torrent.uploaded)
    })
    torrent.on('peer', (addr) => {
      console.log('peer', addr)
    })
    torrent.on('update', (data) => {
      console.log(data)
    })
    torrent.on('noPeers', (type) => {
      console.log(type)
    })
    torrent.on('wire', () => {
      console.log('wire')
    })
    torrent.on('done', () => {
      console.log('Torrent download complete!')
      /*torrent.destroy(() => {
        console.log('Torrent destroyed!')
        client.destroy(() => {
          console.log('client destroyed')
        })
      })*/
    })
  })
  torrent.on('infoHash', () => {
    
  })
  torrent.on('metadata', () => {
    console.log(torrent.bitfield)
    setTimeout(() => console.log(torrent.bitfield), 100)
  })
})


function getContentLength (url) {
  return new Promise((resolve, reject) => {
    fetch(url, {method: 'head', concat: false}, (err, res) => {
      if (err) {
        reject(err)
        return
      }
      const length = +res.headers['content-length']
      if (isFinite(length)) resolve(length)
      else reject(new Error('Content-Length is invalid: ' + res.headers['content-length']))
    })
  })
}

function handleFile (index, file, state) {
  return new Promise((resolve, reject) => {
    const req = fetch(file.url, {concat: false}, (err, res) => {
      if (err) return reject(err)
      const length = +res.headers['content-length']
      const gunzip = zlib.createGunzip()

      let downloaded = 0
      res.on('data', (data) => {
        state.ss.write(data)
        downloaded += data.length
      })
      let stream = res.pipe(gunzip)

      mkdirp(path.join(state.dir, path.dirname(file.filePath)), (err) => {
        if (err) {
          req.abort()
          res.destroy()
          return reject(err)
        }
        const fileStream = fs.createWriteStream(path.join(state.dir, file.filePath))
        stream.pipe(fileStream).once('close', () => resolve(length))
      })

      gunzip.once('error', (err) => {
        state.total += downloaded
        state.ss.setLength(state.total)
        if (state.aborted) resolve(0)
        else reject(err)
        fs.unlink(path.join(state.dir, file.filePath), (unlinkErr) => {
          if (unlinkErr) console.error(unlinkErr)
        })
      })
      res.once('end', () => {
        state.requests.splice(state.requests.indexOf(req), 1)
      })
    })
    state.requests.push(req)
  })
}

fetchVersions().then((versions) => {
  const version = versions['Linux']
  /*const downloader = downloadGameHttp(version, 'torrent/loe', (err) => {
    console.log('Download complete! Abort:', err)
    // app.quit()
  })
  downloader.ss.on('progress', (info) => {
    console.log(info.eta, Math.round(info.speed / 1024) / 1024, info.length)
  })*/
  /*setTimeout(() => {
    downloader.abort()
  }, 2000)*/
})

function fetchVersions () {
  return new Promise((resolve, reject) => {
    fetch('https://patches.legendsofequestria.com/zsync/versions3.json', {}, (err, data) => {
      if (err) return reject(err)
      const versions = JSON.parse(data.toString('utf8'))
      resolve(versions)
    })
  })
}

function downloadGameHttp (version, dir, cb) {
  function abort () {
    state.aborted = true
    state.requests.forEach((req) => !req.aborted && req.abort())
  }
  const ss = progress({
    time: 100,
    drain: true
  })
  const state = {
    total: 0,
    ss: ss,
    aborted: false,
    abort: abort,
    requests: [],
    dir: dir,
    version: version
  }
  const baseUrl = 'https://patches.legendsofequestria.com/zsync/' + version + '/'

  fetch(baseUrl + '.zsync-control.jar', {}, (err, data) => {
    if (err) throw err
    const index = JSON.parse(data.toString('utf8'))
    const files = index.Content.map((file) => {
      return {
        url: baseUrl + path.join('loe', file.RelativeContentUrl).replace(/\.zsync\.jar$/i, ''),
        filePath: path.join('loe', file.RelativeContentUrl).replace(/\.jar\.zsync\.jar$/i, ''),
        fileHash: file.FileHash
      }
    })

    const limitDownload = promiseLimit(3)
    const limitHead = promiseLimit(5)

    Promise.all(files.map((file, i) => limitHead(() => {
      function loop () {
        if (state.aborted) return 0
        return getContentLength(files[i].url).then((fileSize) => {
          files[i].fileSize = fileSize
          state.total += fileSize
          ss.setLength(state.total)
          return fileSize
        }).catch((err) => {
          console.error('Error fetching content-length: ' + err)
          return utils.sleep(5000).then(() => loop()) // Retry after 5 secs
        })
      }
      return loop()
    }))).then(() => {
      if (state.aborted) return
      console.log('Total:', Math.round(state.total / 1024) / 1024, 'MB')
    })

    Promise.all(files.map((file, i) => limitDownload(() => {
      function loop () {
        if (state.aborted) return 0
        return handleFile(i, file, state).catch((err) => {
          console.error('Download interrupted: ' + err)
          return utils.sleep(5000).then(() => loop()) // Retry after 5 secs
        })
      }
      return loop()
    }))).then((results) => {
      cb(state.aborted ? 'aborted' : null)
    })
  })
  return state
}
