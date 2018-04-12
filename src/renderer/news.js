
const fetch = require('simple-get')

const list = document.createElement('div')
const readMore = document.createElement('a')
readMore.href = 'https://forum.legendsofequestria.com/index.php?board=3.0'
readMore.textContent = 'More news'

function addNewsItem (entry, html) {
  html = html || entry.summary[0]._
  html = html.replace(/<\/ul><br><ul class="bbc_list">/ig, '')
  html = html.replace(/<br><br>/ig, '<br>')

  const newsItem = document.createElement('div')
  newsItem.className = 'item'
  const info = document.createElement('div')
  info.className = 'info'
  const link = document.createElement('a')
  link.textContent = entry.title[0].replace(/^Legends of Equestria Changelog/i, 'Changelog')
  link.href = entry.link[0].$.href
  const category = document.createElement('div')
  category.className = 'category'
  category.textContent = entry.category[0].$.term
  info.appendChild(link)
  info.appendChild(category)
  newsItem.appendChild(info)
  const contents = document.createElement('div')
  contents.className = 'contents'
  contents.innerHTML = html
  newsItem.appendChild(contents)
  list.appendChild(newsItem)
}

// fetch news
fetch.concat('https://forum.legendsofequestria.com/index.php?action=.xml;type=atom;sa=news;board=3;limit=3', (err, res, data) => {
  if (err) throw err
  const parseString = require('xml2js').parseString;
  parseString(data.toString('utf8'), (err, result) => {
    if (err) throw err
    const firstEntry = result.feed.entry[0]
    const latestNewsThread = firstEntry.link[0].$.href
    fetch.concat(latestNewsThread, (err, res, data) => {
      if (err) throw err
      let html = data.toString('utf8')
      const ma = html.match(/<div class="post">\n<div class="inner" data-msgid="[0-9]*" id="msg_[0-9]*">(.*)<\/div>\n<\/div>/i)
      html = ma[1]
      addNewsItem(firstEntry, html)
      result.feed.entry.slice(1).forEach((e) => addNewsItem(e))
      emailDecode()
      list.appendChild(readMore)

    })
  })
})

document.addEventListener("DOMContentLoaded", () => {
  document.body.appendChild(list)
}, false)

function emailDecode() {
  // cloudflare email decode
  "use strict";

  function e(e) {
    try {
      if ("undefined" == typeof console) return;
      "error" in console ? console.error(e) : console.log(e)
    } catch (e) {}
  }

  function t(e) {
    return i.innerHTML = '<a href="' + e.replace(/"/g, "&quot;") + '"></a>', i.childNodes[0].getAttribute("href") || ""
  }

  function r(e, t) {
    var r = e.substr(t, 2);
    return parseInt(r, 16)
  }

  function n(n, o) {
    for (var c = "", a = r(n, o), i = o + 2; i < n.length; i += 2) {
      var f = r(n, i) ^ a;
      c += String.fromCharCode(f)
    }
    try {
      c = decodeURIComponent(escape(c))
    } catch (l) {
      e(l)
    }
    return t(c)
  }
  var o = "/cdn-cgi/l/email-protection#",
    c = ".__cf_email__",
    a = "data-cfemail",
    i = document.createElement("div");
  ! function() {
    for (var t = document.getElementsByTagName("a"), r = 0; r < t.length; r++) try {
      var c = t[r],
        a = c.href.indexOf(o);
      a > -1 && (c.href = "mailto:" + n(c.href, a + o.length))
    } catch (i) {
      e(i)
    }
  }(),
  function() {
    for (var t = document.querySelectorAll(c), r = 0; r < t.length; r++) try {
      var o = t[r],
        i = o.parentNode,
        f = o.getAttribute(a);
      if (f) {
        var l = n(f, 0),
          u = document.createTextNode(l);
        i.replaceChild(u, o)
      }
    } catch (d) {
      e(d)
    }
  }()
}
