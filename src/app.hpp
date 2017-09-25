
#ifndef LOE_APP_H
#define LOE_APP_H

#include <thread>
#include <SDL2/SDL.h>

#include "aria2.hpp"

class App {
 private:
  // std::thread downloaderThread_;
  JobQueue jobq_;
  NotifyQueue notifyq_;
  std::mutex mutexStatus;
  SDL_Window* mainWindow = nullptr;
  SDL_Renderer* renderer = nullptr;
  aria2::A2Gid versionsGid;
  std::string currentVersion = "";
 public:
  App();
  ~App();
  int run();
  int downloadThread();
  void handleDownloadEvent(DownloadEvent*);
  void fetchedVersions();
};

#endif
