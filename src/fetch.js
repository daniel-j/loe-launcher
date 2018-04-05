
const http = require('http')
const https = require('https')
const parseUrl = require('url').parse
const concat = require('concat-stream')

function fetch (url, opts = {}, cb) {
  const parsedUrl = parseUrl(url)
  const options = Object.assign(parsedUrl, opts)
  const send = (options.protocol === 'https:' ? https : http).get
  const req = send(options, (res) => {
    if (opts.concat !== false) {
      res.pipe(concat((data) => cb(null, data, res)))
    } else {
      cb(null, res)
    }
  })
  req.on('error', (err) => {
    cb(err)
  })
  req.end()
  return req
}

module.exports = fetch
