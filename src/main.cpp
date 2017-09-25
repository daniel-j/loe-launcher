
#ifdef _WIN32
#define NTDDI_VERSION NTDDI_VISTA
#endif

// #include <experimental/filesystem>

#include "app.hpp"

// namespace fs = std::experimental::filesystem;


/*int downloadEventCallback(aria2::Session* session, aria2::DownloadEvent event,
                          aria2::A2Gid gid, void* userData) {
  switch (event) {
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

/*int AriaThread(std::string torrentfile) {
  int rv;

  {
    std::lock_guard<std::mutex> lock(ariamutex);
    std::cout << "Thread is starting!" << std::endl;
    aria2::libraryInit();
    // session is actually singleton: 1 session per process
    // Create default configuration. The libaria2 takes care of signal
    // handling.
    aria2::SessionConfig config;
    // Add event callback
    config.downloadEventCallback = downloadEventCallback;
    aria2::KeyVals opts;
    opts.push_back(aria2::KeyVals::value_type("no-conf", "true"));
    opts.push_back(aria2::KeyVals::value_type("check-integrity", "true"));
    opts.push_back(aria2::KeyVals::value_type("seed-time", "0"));
    opts.push_back(aria2::KeyVals::value_type("bt-tracker-interval", "10"));
    session = aria2::sessionNew(opts, config);

    // Add download item to session
    aria2::KeyVals options;
    options.push_back(aria2::KeyVals::value_type("dir", "dl"));
    std::cout << "Adding torrent " << torrentfile << std::endl;
    rv = aria2::addTorrent(session, nullptr, torrentfile, options);
    std::cout << "smth" << std::endl;
    if (rv != 0) {
      std::cerr << "Failed to add torrent " << torrentfile << std::endl;
      return 1;
    }
    std::cout << "Torrent added!" << std::endl;
  }

  auto start = std::chrono::steady_clock::now();
  for (;;) {
    std::lock_guard<std::mutex> lock(ariamutex);

    if (session == nullptr || stoparia) {
      break;
    }
    rv = aria2::run(session, aria2::RUN_ONCE);
    if (rv != 1) {
      break;
    }

    std::vector<aria2::A2Gid> gids = aria2::getActiveDownload(session);

    if (gids.size() > 0) {
      aria2::DownloadHandle* dh = aria2::getDownloadHandle(session, gids[0]);
      progress = 1.0f * dh->getCompletedLength() / dh->getTotalLength();
      aria2::deleteDownloadHandle(dh);
      // printf("%f\n", progress * 100);
    }

    auto now = std::chrono::steady_clock::now();
    auto count = std::chrono::duration_cast<std::chrono::milliseconds>(now - start).count();
    aria2::GlobalStat gstat = aria2::getGlobalStat(session);
    // std::vector<aria2::A2Gid> gids = aria2::getActiveDownload(session);

    // Print progress information once per 500ms
    if (count >= 500) {
      start = now;
      std::cerr << "Overall #Active:" << gstat.numActive
                << " #waiting:" << gstat.numWaiting
                << " D:" << gstat.downloadSpeed / 1024 << "KiB/s"
                << " U:" << gstat.uploadSpeed / 1024 << "KiB/s " << std::endl;

      for (const auto& gid : gids) {
        aria2::DownloadHandle* dh = aria2::getDownloadHandle(session, gid);
        if (dh) {
          std::cerr << "    [" << aria2::gidToHex(gid) << "] "
                    << dh->getCompletedLength() << "/" << dh->getTotalLength()
                    << "(" << (dh->getTotalLength() > 0
                                   ? (100 * dh->getCompletedLength() /
                                      dh->getTotalLength())
                                   : 0)
                    << "%)"
                    << " D:" << dh->getDownloadSpeed() / 1024
                    << "KiB/s, U:" << dh->getUploadSpeed() / 1024 << "KiB/s"
                    << std::endl;
          aria2::deleteDownloadHandle(dh);
        }
      }
    }
  }

  {
    std::lock_guard<std::mutex> lock(ariamutex);
    rv = aria2::sessionFinal(session);
    aria2::libraryDeinit();
  }

  return rv;
}*/

int main(int argc, char** argv) {
  App app;
  return app.run();
}
