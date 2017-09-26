
#ifndef LOE_APP_H
#define LOE_APP_H

#include <thread>
#include <SDL2/SDL.h>

#include "aria2.hpp"

class App {
 private:
  Downloader downloader;
  SDL_Window* mainWindow = nullptr;
  SDL_Renderer* renderer = nullptr;
  std::string latestVersion = "";
 public:
  App();
  ~App();
  int run();
  void fetchedVersions();
};

#endif
