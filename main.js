const {app, BrowserWindow} = require('electron')

const fs = require('fs')
const path = require('path')
const zlib = require('zlib')
const concat = require('concat-stream')
const mkdirp = require('mkdirp')
const progress = require('progress-stream')
const chunker = require('stream-chunker')
const crypto = require('crypto')
const fetch = require('./src/fetch')

const dir = 'loe'

function getContentSize (url) {
  return new Promise((resolve, reject) => {
    fetch(url, {method: 'head', concat: false}, (err, res) => {
      if (err) {
        reject(err)
        return
      }
      resolve(+res.headers['content-length'])
    })
  })
}

fetch('https://patches.legendsofequestria.com/zsync/versions3.json', {}, (err, data) => {
  if (err) throw err
  const versions = JSON.parse(data.toString('utf8'))
  const baseUrl = 'https://patches.legendsofequestria.com/zsync/' + versions['Linux'] + '/'
  console.log(versions)
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
    const ss = progress({
      time: 200
    })
    ss.on('progress', (info) => {
      console.log(info.eta, Math.round(info.speed / 1024) / 1024)
    })
    let total = 0
    /*
    for (let i = 0; i < files.length; i++) {
      files[i].fileSize = await getContentSize(files[i].url)
      total += files[i].fileSize
      console.log(files[i].filePath, total)
    }
    */
    const file = files[0]
    mkdirp(path.join(dir, path.dirname(file.filePath)), (err) => {
      if (err) throw err
      console.log(file)
      /*fetch(file.url + '.zsync.jar', {}, (err, data, res) => {
        console.log(data.toString('utf8').split('\n\n')[0])
      })*/
      fetch(file.url, {concat: false}, (err, res) => {
        const total = +res.headers['content-length']
        ss.setLength(total)
        res
          .pipe(ss)
          .pipe(zlib.createGunzip())
          .pipe(fs.createWriteStream(path.join(dir, file.filePath)))
          .once('close', () => console.log('complete!'))
      })
    })
    /*let h = 'b0b43933efc4bbc47555e5ee6506d584e038dac9'
    let blockSize = 2048
    let stream = fs.createReadStream(path.join('loe', file.filePath))
      .pipe(chunker(blockSize))
      .pipe(zlib.createGzip({
        chunkSize: blockSize,
        flush: zlib.constants.Z_PARTIAL_FLUSH,
        level: 9,
        method: zlib.constants.Z_DEFLATED,
        // windowBits: -15,
        memoryLevel: 8,
        strategy: zlib.constants.Z_DEFAULT_STRATEGY
      }))
    hash = crypto.createHash('sha1')
    hash.setEncoding('hex')
    stream.on('end', () => {
      hash.end()
      console.log(hash.read())
    })
    stream.pipe(hash)
    stream.pipe(concat((data) => {
      console.log('node', data)
    }))
    */
  })
})

// app.quit()
