// const {app, BrowserWindow} = require('electron')

const fs = require('fs')
const path = require('path')
const zlib = require('zlib')
const mkdirp = require('mkdirp')
const progress = require('progress-stream')
const promiseLimit = require('promise-limit')
const fetch = require('simple-get')
const sleep = require('./utils/sleep')

function getCurrentVersion () {
  const arch = require('arch')
  if (process.platform === 'darwin') return 'macos'
  else if (process.platform === 'win32') return (arch() === 'x64' ? 'win64' : 'win32')
  else return 'linux'
}

/*
// MEGA downloader
const mega = require('megajs')
const unzip = require('unzip').Extract
const rimraf = require('rimraf')

fetch.concat('https://www.legendsofequestria.com/downloads', (err, res, data) => {
  if (err) throw err
  let html = data.toString('utf8')
  const megaReg = /<a href="(https:\/\/mega\.nz\/#![a-zA-Z0-9_-]*![a-zA-Z0-9_-]*)">(.*?)<\/a>/ig
  const versions = {}
  for (let ma; (ma = megaReg.exec(html));) {
    let key = ma[2].trim().toLowerCase()
    if (key === 'windows x32') key = 'win32'
    else if (key === 'windows x64') key = 'win64'
    versions[key] = ma[1]
  }
  const version = getCurrentVersion()
  const megaUrl = versions[version]
  if (!megaUrl) throw new Error('MEGA: No version found!')
  const file = mega.File.fromURL(megaUrl)
  file.loadAttributes((err) => {
    if (err) throw err
    const dlDir = 'dl' // should be set to local user cache
    const zipfile = path.join(dlDir, 'download.zip')

    function extractAndRemove () {
      let dir = 'dl/loe'
      console.log('Removing ' + dir)
      rimraf(dir, (err) => {
        if (err) throw err
        console.log('Extracting...', zipfile)
        let stream = fs.createReadStream(zipfile).pipe(unzip({
          path: dir,
          verbose: true
        }))
        stream.on('error', (err) => {
          console.log('unzip error:', err)
        })
        stream.on('close', () => {
          if (version === 'macos') {
            fs.chmodSync(path.join(dir, 'loe.app/Contents/MacOS/loe'), 0o755)
          } else if (version === 'linux') {
            fs.chmodSync(path.join(dir, 'loe.x86'), 0o755)
            fs.chmodSync(path.join(dir, 'loe.x86_64'), 0o755)
          }
          console.log('Removing', zipfile)
          fs.unlink(zipfile, (err) => {
            if (err) throw err
            console.log('Finished!')
          })
        })
      })
    }

    mkdirp(dlDir, (err) => {
      if (err) throw err
      let start = 0
      try {
        start = fs.statSync(zipfile).size
      } catch (err) {}

      fs.readFile(path.join(dlDir, 'version.txt'), 'utf8', (err, data) => {
        if (err) {}
        if (data !== megaUrl) {
          // restart download, new version
          start = 0
        }
        fs.writeFile(path.join(dlDir, 'version.txt'), Buffer.from(megaUrl, 'utf8'), (err) => {
          if (err) throw err

          console.log(file.downloadId)
          console.log(file.name, Math.round(file.size / 1024 / 1024) + ' MB')

          if (start >= file.size) return extractAndRemove()
          const ss = progress({
            time: 1000,
            length: file.size,
            transferred: start
          })
          ss.on('progress', (info) => {
            console.log(Math.round(info.eta / 60 * 10) / 10, Math.round(info.percentage * 10) / 10 + ' %', Math.round(info.speed / 1024 / 1024 * 100) / 100 + ' MB/s')
          })
          let stream = file.download({start})
          stream.pipe(ss).pipe(fs.createWriteStream(zipfile, {flags: start > 0 ? 'r+' : 'w', start}))
          stream.once('end', () => {
            if (ss.progress().remaining !== 0) throw new Error('Remaining is not 0')
            extractAndRemove()
          })
        })
      })
    })
  })
})
*/

/*
const WebTorrent = require('webtorrent')

const client = new WebTorrent({
  webSeeds: true,
  dht: false,
  tracker: false
})

client.on('error', (err) => {
  console.error(err)
})

fetch.concat('https://djazz.se/nas/games/loe/loe-linux.torrent', (err, res, data) => {
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
*/

function getContentLength (url) {
  return new Promise((resolve, reject) => {
    fetch({method: 'head', url}, (err, res) => {
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
    const req = fetch(file.url, (err, res) => {
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

function fetchVersions () {
  return new Promise((resolve, reject) => {
    fetch.concat({url: 'https://patches.legendsofequestria.com/zsync/versions3.json', json: true}, (err, res, data) => {
      if (err) return reject(err)
      const versions = {}
      for (let i in data) {
        let key = i.toLowerCase()
        if (key === 'mac') key = 'macos'
        versions[key] = data[i]
      }
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

  fetch.concat({url: baseUrl + '.zsync-control.jar', json: true}, (err, res, index) => {
    if (err) throw err
    const files = index.Content.map((file, i) => {
      return {
        url: baseUrl + path.join('loe', file.RelativeContentUrl).replace(/\.zsync\.jar$/i, ''),
        filePath: path.join(file._installPath.replace(/\\/g, '/').replace(/\.jar\.zsync\.jar$/i, '')),
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
          return sleep(5000).then(() => loop()) // Retry after 5 secs
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
          return sleep(5000).then(() => loop()) // Retry after 5 secs
        })
      }
      return loop()
    }))).then((results) => {
      cb(state.aborted ? 'aborted' : null)
    })
  })
  return state
}

/*
fetchVersions().then((versions) => {
  const version = versions[getCurrentVersion()]
  if (!version) throw new Error('Bad version!')
  const downloader = downloadGameHttp(version, 'zsync/loe', (err) => {
    console.log('Download complete! Abort:', err)
  })
  downloader.ss.on('progress', (info) => {
    console.log(info.eta, Math.round(info.speed / 1024) / 1024, info.length)
  })
})
*/
