
#include "aria2.hpp"

/*
std::mutex ariamutex;

template <typename T> std::string abbrevsize(T size) {
  if (size >= 1024 * 1024 * 1024) {
    return std::to_string(size / 1024 / 1024 / 1024) + "G";
  }
  else if (size >= 1024 * 1024) {
    return std::to_string(size / 1024 / 1024) + "M";
  }
  else if (size >= 1024) {
    return std::to_string(size / 1024) + "K";
  }
  else {
    return std::to_string(size);
  }
}

int downloadEventCallback(aria2::Session* session, aria2::DownloadEvent event,
                          aria2::A2Gid gid, void* userData) {
  auto notifyq = static_cast<NotifyQueue*>(userData);
  auto ev = new DownloadEvent;
  ev->event = std::move(event);
  ev->gid = std::move(gid);
  // notifyq->push(std::unique_ptr<Notification>(new Notification(DownloadEventNotification, ev)));

  return 0;


  switch (event) {
    case aria2::EVENT_ON_DOWNLOAD_START:
      std::cerr << "STARTED";
      break;
    case aria2::EVENT_ON_DOWNLOAD_COMPLETE:
      std::cerr << "COMPLETE";
      break;
    case aria2::EVENT_ON_DOWNLOAD_ERROR:
      std::cerr << "ERROR";
      break;
    default:
      return 0;
  }
  std::cerr << " [" << aria2::gidToHex(gid) << "] ";
  aria2::DownloadHandle* dh = aria2::getDownloadHandle(session, gid);
  if (!dh)
    return 0;
  if (dh->getNumFiles() > 0) {
    aria2::FileData f = dh->getFile(1);
    // Path may be empty if the file name has not been determined yet.
    if (f.path.empty()) {
      if (!f.uris.empty()) {
        std::cerr << f.uris[0].uri;
      }
    } else {
      std::cerr << f.path;
    }
  }
  aria2::deleteDownloadHandle(dh);
  std::cerr << std::endl;

  return 0;
}*/

/*
int ariaWorker(JobQueue& jobq, NotifyQueue& notifyq) {
  aria2::libraryInit();
  // session is actually singleton: 1 session per process
  aria2::Session* session;
  // Use default configuration
  aria2::SessionConfig config;
  config.keepRunning = true;
  config.userData = (void*)&notifyq;
  config.downloadEventCallback = downloadEventCallback;
  aria2::KeyVals opts;
  opts.push_back(std::make_pair("no-conf", "true"));
  opts.push_back(std::make_pair("check-integrity", "true"));
  opts.push_back(std::make_pair("seed-time", "0"));
  opts.push_back(std::make_pair("bt-tracker-interval", "10"));
  opts.push_back(std::make_pair("allow-overwrite", "true"));
  opts.push_back(std::make_pair("auto-file-renaming", "false"));
  opts.push_back(std::make_pair("follow-torrent", "mem"));

  session = aria2::sessionNew(opts, config);

  auto start = std::chrono::steady_clock::now();
  for (;;) {
    int rv = aria2::run(session, aria2::RUN_ONCE);
    if (rv != 1) {
      break;
    }
    auto now = std::chrono::steady_clock::now();
    auto count = std::chrono::duration_cast<std::chrono::milliseconds>(now - start).count();
    while (!jobq.empty()) {
      std::unique_ptr<Job> job = jobq.pop();
      job->execute(session);
    }
    if (count >= 900) {
      start = now;
      std::vector<aria2::A2Gid> gids = aria2::getActiveDownload(session);
      std::vector<DownloadStatus> v;
      for (auto gid : gids) {
        aria2::DownloadHandle* dh = aria2::getDownloadHandle(session, gid);
        if (dh) {
          DownloadStatus st;
          st.gid = gid;
          st.totalLength = dh->getTotalLength();
          st.completedLength = dh->getCompletedLength();
          st.downloadSpeed = dh->getDownloadSpeed();
          st.uploadSpeed = dh->getUploadSpeed();
          if (dh->getNumFiles() > 0) {
            aria2::FileData file = dh->getFile(1);
            st.filename = file.path;
          }
          v.push_back(std::move(st));
          aria2::deleteDownloadHandle(dh);
        }
      }
      //notifyq.push(std::unique_ptr<Notification>(
      //    new DownloadStatusNotification(std::move(v))));
    }
  }
  int rv = aria2::sessionFinal(session);
  // Report back to the UI thread that this thread is going to
  // exit. This is needed when user pressed ctrl-C in the terminal.
  //notifyq.push(std::unique_ptr<Notification>(new ShutdownNotification()));
  return rv;
}
*/


Downloader::~Downloader() {
  keepRunning = false;
  if (threadRef) {
    threadRef->join();
    delete threadRef;
  }
  aria2::libraryDeinit();
}

void Downloader::begin() {
  threadRef = new std::thread(&Downloader::threadFunc, this);
}

int Downloader::downloadEventCallback(aria2::Session* session, aria2::DownloadEvent event,
                                      aria2::A2Gid gid, void* userData) {
  auto self = (Downloader*)userData;
  std::lock_guard<std::mutex> l(self->m_);

  auto cb = self->callbacks[gid];

  if (cb && event == aria2::EVENT_ON_DOWNLOAD_COMPLETE) {
    cb(true);
  } else if (cb && event == aria2::EVENT_ON_DOWNLOAD_ERROR) {
    cb(false);
  }

  return 0;
}

void addUri(std::vector<std::string> uris, aria2::KeyVals& options, aria2::A2Gid* g, FetchCallback& callback) {
  std::cout << "hi from adduri!" << std::endl;
}

void Downloader::fetch(std::string uri, std::string filepath, FetchCallback callback) {
  std::vector<std::string> uris = {uri};
  aria2::KeyVals options;
  options.push_back(std::make_pair("out", filepath));
  // jobq.push(std::unique_ptr<Job>(new AddUriJob(std::move(uris), std::move(options), &gid, std::move(callback))));
  jobq.push([=]() {
    aria2::A2Gid gid;
    int rv = aria2::addUri(session, &gid, uris, options);
    if (rv != 0) {
      std::cerr << "aria2: Failed to add uri " << uri << std::endl;
      callback(false);
      return;
    } else {
      callbacks[gid] = callback;
      // callback(aria2::gidToHex(*gid));
      std::cout << aria2::gidToHex(gid) << std::endl;
    }
  });
}

void Downloader::threadFunc() {
  aria2::libraryInit();

  aria2::SessionConfig config;
  config.keepRunning = true;
  config.userData = (void*)this;
  config.downloadEventCallback = &Downloader::downloadEventCallback;

  aria2::KeyVals opts;
  opts.push_back(std::make_pair("no-conf", "true"));
  opts.push_back(std::make_pair("check-integrity", "true"));
  opts.push_back(std::make_pair("seed-time", "0"));
  opts.push_back(std::make_pair("bt-tracker-interval", "10"));
  opts.push_back(std::make_pair("allow-overwrite", "true"));
  opts.push_back(std::make_pair("auto-file-renaming", "false"));
  opts.push_back(std::make_pair("follow-torrent", "mem"));

  session = aria2::sessionNew(opts, config);
  for (;;) {
    if (!keepRunning) break;
    int rv = aria2::run(session, aria2::RUN_ONCE);
    if (rv != 1) {
      break;
    }
    while (!jobq.empty()) {
      auto job = jobq.pop();
      //job->execute(session, this);
      job();
    }
  }
  int rv = aria2::sessionFinal(session);
}
