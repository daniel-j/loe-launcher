
#include <mutex>

#include "aria2.hpp"

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
  notifyq->push(std::unique_ptr<Notification>(new Notification(DownloadEventNotification, ev)));

  return 0;

  /*
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
  */
}

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
