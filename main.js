// const {app, BrowserWindow} = require('electron')

const fs = require('fs')
const path = require('path')
const zlib = require('zlib')
const mkdirp = require('mkdirp')
const progress = require('progress-stream')
const promiseLimit = require('promise-limit')
const fetch = require('./src/fetch')
const utils = require('./src/utils')
const concat = require('concat-stream')

/*
const mega = require('megajs')

const file = mega.File.fromURL('https://mega.nz/#!5yYVABiC!94LcCKDUfeM2nYAt1VjpjC_5cB6h2beI3ATRPYsAt9A')
file.loadAttributes((err) => {
  console.log(file.name, file.size / 1024 / 1024)
  let start = 0
  try {
    start = fs.statSync(file.name).size
  } catch (err) {}
  if (start >= file.size) return
  file.download({start}).pipe(fs.createWriteStream(file.name, {flags: 'r+', start}))
})
*/

const WebTorrent = require('webtorrent')

const client = new WebTorrent({
  webSeeds: true,
  dht: false,
  tracker: false
})

client.on('error', (err) => {
  console.error(err)
})

fetch('https://djazz.se/nas/games/loe/loe-linux.torrent', {}, (err, data) => {
  if (err) throw err
  let ready = false
  let gotMetadata = false
  const torrent = client.add(data, {path: 'torrent'}, () => {
    console.log('Ready!')
    ready = true
  })
  let timer = setInterval(() => {
    if (!ready && gotMetadata) {
      console.log('Verifying...', Math.round(torrent.progress * 100) + '%')
    } else if (ready && torrent.downloadSpeed > 0) {
      console.log(torrent.numPeers + ' peer(s),', Math.round(torrent.timeRemaining / 1000 / 60) + ' min,', Math.round(torrent.progress * 100) + '%,', Math.round(torrent.downloaded / 1024 / 1024) + ' MB downloaded,', torrent.downloadSpeed / 1024 / 1024 + ' MB/s')
    }
  }, 1000)
  torrent.on('warning', (warn) => {
    console.warn('webtorrent warn: ' + warn)
  })
  torrent.on('error', (err) => {
    clearInterval(timer)
    console.error(err)
  })
  torrent.on('download', (bytes) => {
    
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
  torrent.on('wire', (wire, addr) => {
    console.log('wire', addr, wire.type)
    wire.on('bitfield', (bitfield) => {
      // console.log('got bitfield from wire', addr)
    })
    wire.on('piece', (index, offset) => {
      // console.log('piece from wire', index, offset)
    })
    wire.once('close', () => {
      console.log('wire closed!', addr)
    })
  })
  torrent.on('done', () => {
    console.log('Torrent download complete! Seeding...')
    torrent.destroy(() => {
      clearInterval(timer)
      console.log('Torrent destroyed!')
      client.destroy(() => {
        console.log('client destroyed')
      })
    })
  })
  torrent.on('infoHash', () => {

  })
  torrent.on('metadata', () => {
    gotMetadata = true
    console.log('Got metadata')
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
    console.log(file.url)
    const req = fetch(file.url, {concat: false}, (err, res) => {
      if (err) return reject(err)
      const length = +res.headers['content-length']
      const gunzip = zlib.createGunzip()

      let downloaded = 0
      res.pipe(concat((data) => {
        console.log(data)
        let buf = zlib.gzipSync(zlib.gunzipSync(data).slice(0, 2048), {
          // flush: zlib.constants.Z_PARTIAL_FLUSH,
          // chunkSize: 2048,
          memLevel: 8,
          windowBits: 15,
          level: 9
        })
        console.log(buf)

        let d = zlib.createDeflateRaw({
          flush: zlib.constants.Z_PARTIAL_FLUSH,
          // chunkSize: 2048,
          memLevel: 8,
          windowBits: 15,
          level: 9
        })
        
        d.pipe(concat((buf) => {
          console.log(buf)
        }))
        d.write(zlib.gunzipSync(data).slice(0, 2048))
        d.flush()
        d.write(zlib.gunzipSync(data).slice(2048, 2048 * 2))
        d.end()
      }))
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
  /*
  const version = versions['Linux']
  const downloader = downloadGameHttp(version, 'zsync/loe', (err) => {
    console.log('Download complete! Abort:', err)
    // app.quit()
  })
  downloader.ss.on('progress', (info) => {
    console.log(info.eta, Math.round(info.speed / 1024) / 1024, info.length)
  })
  */

  /*
  setTimeout(() => {
    downloader.abort()
  }, 2000)
  */
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
    const files = index.Content.map((file, i) => {
      console.log(i, file.RelativeContentUrl)
      return {
        url: baseUrl + path.join('loe', file.RelativeContentUrl).replace(/\.zsync\.jar$/i, ''),
        filePath: path.join('loe', file.RelativeContentUrl).replace(/\.jar\.zsync\.jar$/i, ''),
        fileHash: file.FileHash
      }
    }).slice(166, 167)

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
